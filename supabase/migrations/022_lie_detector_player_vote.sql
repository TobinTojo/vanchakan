-- Lie detector player phase: group votes on who they think gave the evidence answer

CREATE OR REPLACE FUNCTION get_lie_detector_state(p_room_id UUID)
RETURNS JSON AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_selected_evidence JSON;
  v_evidence_id UUID;
BEGIN
  SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
  IF NOT FOUND OR v_room.status != 'lie_detector' THEN RETURN NULL; END IF;

  SELECT target_evidence_id INTO v_evidence_id FROM lie_detector_results
  WHERE room_id = p_room_id AND event_number = v_room.lie_detector_event AND result_phase = 'evidence';

  IF v_evidence_id IS NOT NULL THEN
    SELECT json_build_object(
      'evidence_id', e.id,
      'evidence_order', e.evidence_order,
      'question_id', e.question_id,
      'question_text', q.question_text,
      'answer_text', e.answer_text,
      'inspection_result', lr.inspection_result
    ) INTO v_selected_evidence
    FROM lie_detector_results lr
    JOIN evidence e ON e.id = lr.target_evidence_id
    LEFT JOIN questions q ON q.id = e.question_id
    WHERE lr.room_id = p_room_id
      AND lr.event_number = v_room.lie_detector_event
      AND lr.result_phase = 'evidence';
  END IF;

  RETURN json_build_object(
    'step', COALESCE(v_room.lie_detector_step, 'vote_evidence'),
    'event_number', v_room.lie_detector_event,
    'phase_ends_at', v_room.phase_ends_at,
    'evidence_options', get_lie_detector_evidence_options(p_room_id),
    'evidence_result', get_lie_detector_result(p_room_id, v_room.lie_detector_event, 'evidence'),
    'player_result', get_lie_detector_result(p_room_id, v_room.lie_detector_event, 'player'),
    'selected_evidence', v_selected_evidence
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_lie_detector_vote(
  p_player_id UUID,
  p_session_token TEXT,
  p_action lie_detector_action,
  p_target_evidence_id UUID DEFAULT NULL,
  p_target_player_id UUID DEFAULT NULL,
  p_target_question_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_step TEXT;
  v_max_round INT;
  v_evidence_question UUID;
  v_vote_phase TEXT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'lie_detector' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  v_step := COALESCE(v_room.lie_detector_step, 'vote_evidence');
  v_max_round := CASE WHEN v_room.lie_detector_event = 1 THEN 3 ELSE 6 END;

  IF v_step = 'vote_evidence' THEN
    IF p_action != 'inspect_evidence' OR p_target_evidence_id IS NULL THEN
      RAISE EXCEPTION 'INVALID_VOTE';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM interrogation_rounds ir
      WHERE ir.room_id = v_player.room_id
        AND ir.evidence_id = p_target_evidence_id
        AND ir.suspect_player_id IS NOT NULL
        AND ir.round_number <= v_max_round
    ) THEN
      RAISE EXCEPTION 'INVALID_EVIDENCE';
    END IF;

    v_vote_phase := 'evidence';

    INSERT INTO lie_detector_votes (
      room_id, event_number, player_id, action_type, vote_phase,
      target_evidence_id, target_player_id, target_question_id
    )
    VALUES (
      v_player.room_id, v_room.lie_detector_event, p_player_id, p_action, v_vote_phase,
      p_target_evidence_id, NULL, NULL
    )
    ON CONFLICT (room_id, event_number, player_id, vote_phase) DO UPDATE SET
      action_type = EXCLUDED.action_type,
      target_evidence_id = EXCLUDED.target_evidence_id,
      target_player_id = NULL,
      target_question_id = NULL,
      submitted_at = now();

  ELSIF v_step = 'vote_player' THEN
    IF p_action != 'check_answer' OR p_target_player_id IS NULL THEN
      RAISE EXCEPTION 'INVALID_VOTE';
    END IF;

    IF p_target_player_id = p_player_id THEN
      RAISE EXCEPTION 'INVALID_PLAYER';
    END IF;

    SELECT e.question_id INTO v_evidence_question
    FROM lie_detector_results lr
    JOIN evidence e ON e.id = lr.target_evidence_id
    WHERE lr.room_id = v_player.room_id
      AND lr.event_number = v_room.lie_detector_event
      AND lr.result_phase = 'evidence';

    IF v_evidence_question IS NULL THEN
      RAISE EXCEPTION 'INVALID_STATE';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM players
      WHERE id = p_target_player_id
        AND room_id = v_player.room_id
        AND is_connected = true
    ) THEN
      RAISE EXCEPTION 'INVALID_PLAYER';
    END IF;

    v_vote_phase := 'player';

    INSERT INTO lie_detector_votes (
      room_id, event_number, player_id, action_type, vote_phase,
      target_evidence_id, target_player_id, target_question_id
    )
    VALUES (
      v_player.room_id, v_room.lie_detector_event, p_player_id, p_action, v_vote_phase,
      NULL, p_target_player_id, v_evidence_question
    )
    ON CONFLICT (room_id, event_number, player_id, vote_phase) DO UPDATE SET
      action_type = EXCLUDED.action_type,
      target_evidence_id = NULL,
      target_player_id = EXCLUDED.target_player_id,
      target_question_id = EXCLUDED.target_question_id,
      submitted_at = now();

  ELSE
    RAISE EXCEPTION 'INVALID_STATE';
  END IF;

  PERFORM try_resolve_lie_detector(v_player.room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION try_resolve_lie_detector(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_voted INT;
  v_connected INT;
  v_step TEXT;
  v_host UUID;
  v_event INT;
  v_evidence_id UUID;
  v_target_player UUID;
  v_target_question UUID;
  v_criminal UUID;
  v_player_name TEXT;
  v_question_text TEXT;
  v_answer_text TEXT;
  v_criminal_answer TEXT;
  v_verdict TEXT;
  v_inspection TEXT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_ld'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'lie_detector' THEN RETURN; END IF;

  v_event := v_room.lie_detector_event;
  v_step := COALESCE(v_room.lie_detector_step, 'vote_evidence');
  v_criminal := get_room_criminal(p_room_id);

  IF v_step IN ('reveal_evidence', 'reveal_player') THEN
    IF v_room.phase_ends_at IS NOT NULL AND v_room.phase_ends_at > now() THEN RETURN; END IF;

    IF v_step = 'reveal_evidence' THEN
      UPDATE rooms SET lie_detector_step = 'vote_player', phase_ends_at = NULL, updated_at = now()
      WHERE id = p_room_id;
      RETURN;
    END IF;

    SELECT host_player_id INTO v_host FROM rooms WHERE id = p_room_id;

    UPDATE rooms SET
      status = CASE WHEN v_room.current_round >= 6 THEN 'suspect_vote' ELSE 'interrogation' END,
      current_round = CASE WHEN v_room.current_round >= 6 THEN v_room.current_round ELSE v_room.current_round + 1 END,
      lie_detector_step = NULL,
      phase_ends_at = CASE WHEN v_room.current_round >= 6 THEN now() + interval '45 seconds' ELSE NULL END,
      updated_at = now()
    WHERE id = p_room_id AND status = 'lie_detector';

    IF v_room.current_round < 6 AND v_host IS NOT NULL THEN
      PERFORM start_interrogation_round(v_host, (SELECT session_token FROM players WHERE id = v_host));
    END IF;
    RETURN;
  END IF;

  IF v_step = 'vote_evidence' THEN
    SELECT COUNT(*) INTO v_voted FROM lie_detector_votes
    WHERE room_id = p_room_id AND event_number = v_event AND vote_phase = 'evidence';
    SELECT COUNT(*) INTO v_connected FROM players WHERE room_id = p_room_id AND is_connected = true;

    IF v_voted < v_connected THEN RETURN; END IF;

    SELECT target_evidence_id INTO v_evidence_id FROM lie_detector_votes
    WHERE room_id = p_room_id AND event_number = v_event AND vote_phase = 'evidence'
    GROUP BY target_evidence_id ORDER BY COUNT(*) DESC LIMIT 1;

    IF v_evidence_id IS NOT NULL THEN
      UPDATE evidence SET is_inspected = true,
        inspection_result = CASE WHEN is_fake THEN 'Fake Evidence' ELSE 'Genuine Evidence' END
      WHERE id = v_evidence_id
      RETURNING inspection_result INTO v_inspection;

      INSERT INTO lie_detector_results (
        room_id, event_number, result_phase, action_type, target_evidence_id, inspection_result
      ) VALUES (
        p_room_id, v_event, 'evidence', 'inspect_evidence', v_evidence_id, v_inspection
      )
      ON CONFLICT (room_id, event_number, result_phase) DO UPDATE SET
        action_type = EXCLUDED.action_type,
        target_evidence_id = EXCLUDED.target_evidence_id,
        inspection_result = EXCLUDED.inspection_result;
    END IF;

    UPDATE rooms SET lie_detector_step = 'reveal_evidence', phase_ends_at = now() + interval '12 seconds', updated_at = now()
    WHERE id = p_room_id;
    RETURN;
  END IF;

  IF v_step = 'vote_player' THEN
    SELECT COUNT(*) INTO v_voted FROM lie_detector_votes
    WHERE room_id = p_room_id AND event_number = v_event AND vote_phase = 'player';
    SELECT COUNT(*) INTO v_connected FROM players WHERE room_id = p_room_id AND is_connected = true;

    IF v_voted < v_connected THEN RETURN; END IF;

    SELECT ld.target_player_id INTO v_target_player
    FROM lie_detector_votes ld
    WHERE ld.room_id = p_room_id AND ld.event_number = v_event AND ld.vote_phase = 'player'
    GROUP BY ld.target_player_id
    ORDER BY COUNT(*) DESC LIMIT 1;

    SELECT e.question_id INTO v_target_question
    FROM lie_detector_results lr
    JOIN evidence e ON e.id = lr.target_evidence_id
    WHERE lr.room_id = p_room_id AND lr.event_number = v_event AND lr.result_phase = 'evidence';

    IF v_target_player IS NOT NULL AND v_target_question IS NOT NULL THEN
      SELECT p.display_name, q.question_text, pa.answer_text
      INTO v_player_name, v_question_text, v_answer_text
      FROM players p
      JOIN questions q ON q.id = v_target_question
      LEFT JOIN player_answers pa ON pa.player_id = v_target_player
        AND pa.question_id = v_target_question AND pa.room_id = p_room_id
      WHERE p.id = v_target_player;

      IF v_criminal IS NOT NULL THEN
        SELECT pa.answer_text INTO v_criminal_answer
        FROM player_answers pa
        WHERE pa.room_id = p_room_id AND pa.question_id = v_target_question
          AND pa.player_id = v_criminal;
      END IF;

      IF v_criminal_answer IS NOT NULL
         AND lower(trim(COALESCE(v_answer_text, ''))) = lower(trim(v_criminal_answer)) THEN
        v_verdict := 'dishonest';
      ELSE
        v_verdict := 'honest';
      END IF;

      INSERT INTO lie_detector_results (
        room_id, event_number, result_phase, action_type,
        target_player_id, target_question_id,
        player_name, question_text, answer_text, answer_verdict
      ) VALUES (
        p_room_id, v_event, 'player', 'check_answer',
        v_target_player, v_target_question,
        v_player_name, v_question_text, COALESCE(v_answer_text, 'No answer'), v_verdict
      )
      ON CONFLICT (room_id, event_number, result_phase) DO UPDATE SET
        action_type = EXCLUDED.action_type,
        target_player_id = EXCLUDED.target_player_id,
        target_question_id = EXCLUDED.target_question_id,
        player_name = EXCLUDED.player_name,
        question_text = EXCLUDED.question_text,
        answer_text = EXCLUDED.answer_text,
        answer_verdict = EXCLUDED.answer_verdict;
    END IF;

    UPDATE rooms SET lie_detector_step = 'reveal_player', phase_ends_at = now() + interval '12 seconds', updated_at = now()
    WHERE id = p_room_id;
    RETURN;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
