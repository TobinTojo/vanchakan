-- Survey: no timer, advance when all answer
-- Interrogation: auto-end round when timer expires
-- Lie detector: two-phase vote (evidence then attached player)

ALTER TABLE rooms ADD COLUMN IF NOT EXISTS lie_detector_step TEXT;

ALTER TABLE lie_detector_votes ADD COLUMN IF NOT EXISTS vote_phase TEXT NOT NULL DEFAULT 'evidence';

ALTER TABLE lie_detector_votes DROP CONSTRAINT IF EXISTS lie_detector_votes_room_id_event_number_player_id_key;
ALTER TABLE lie_detector_votes DROP CONSTRAINT IF EXISTS lie_detector_votes_unique;
ALTER TABLE lie_detector_votes
  ADD CONSTRAINT lie_detector_votes_unique UNIQUE (room_id, event_number, player_id, vote_phase);

ALTER TABLE lie_detector_results ADD COLUMN IF NOT EXISTS result_phase TEXT NOT NULL DEFAULT 'evidence';
ALTER TABLE lie_detector_results DROP CONSTRAINT IF EXISTS lie_detector_results_pkey;
ALTER TABLE lie_detector_results ADD PRIMARY KEY (room_id, event_number, result_phase);

-- Survey: no per-question timer; advance only when everyone has answered
CREATE OR REPLACE FUNCTION advance_survey_question(
  p_player_id UUID,
  p_session_token TEXT,
  p_force BOOLEAN DEFAULT false
)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_gq game_questions%ROWTYPE;
  v_now TIMESTAMPTZ := now();
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'survey' THEN RETURN; END IF;

  SELECT * INTO v_gq FROM game_questions
  WHERE room_id = v_player.room_id AND question_order = v_room.current_question_index;

  IF NOT FOUND THEN RETURN; END IF;

  IF NOT p_force THEN RETURN; END IF;

  IF v_gq.started_at IS NOT NULL THEN
    INSERT INTO player_answers (room_id, player_id, question_id, answer_text)
    SELECT v_player.room_id, p.id, v_gq.question_id, 'No answer'
    FROM players p
    WHERE p.room_id = v_player.room_id AND p.is_connected = true
    AND NOT EXISTS (
      SELECT 1 FROM player_answers pa
      WHERE pa.room_id = v_player.room_id AND pa.player_id = p.id AND pa.question_id = v_gq.question_id
    )
    ON CONFLICT (room_id, player_id, question_id) DO NOTHING;
  END IF;

  IF v_room.current_question_index >= 8 THEN
    PERFORM finish_survey(v_player.room_id);
    RETURN;
  END IF;

  IF v_gq.started_at IS NOT NULL THEN
    UPDATE rooms SET current_question_index = current_question_index + 1, updated_at = now()
    WHERE id = v_player.room_id AND status = 'survey';

    SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
    SELECT * INTO v_gq FROM game_questions
    WHERE room_id = v_player.room_id AND question_order = v_room.current_question_index;

    IF NOT FOUND THEN RETURN; END IF;
  END IF;

  UPDATE game_questions SET started_at = v_now, ends_at = NULL WHERE id = v_gq.id;
  UPDATE rooms SET phase_ends_at = NULL, updated_at = now()
  WHERE id = v_player.room_id AND status = 'survey';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_answer(p_player_id UUID, p_session_token TEXT, p_answer_text TEXT)
RETURNS JSON AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_gq game_questions%ROWTYPE;
  v_answered INT;
  v_connected INT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'survey' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  SELECT * INTO v_gq FROM game_questions
  WHERE room_id = v_player.room_id AND question_order = v_room.current_question_index;

  IF v_gq.started_at IS NULL THEN RAISE EXCEPTION 'QUESTION_NOT_STARTED'; END IF;

  INSERT INTO player_answers (room_id, player_id, question_id, answer_text)
  VALUES (v_player.room_id, p_player_id, v_gq.question_id, trim(p_answer_text))
  ON CONFLICT (room_id, player_id, question_id) DO NOTHING;

  SELECT COUNT(*) INTO v_answered FROM player_answers pa
  JOIN game_questions gq ON gq.question_id = pa.question_id AND gq.room_id = pa.room_id
  WHERE pa.room_id = v_player.room_id AND gq.question_order = v_room.current_question_index;

  SELECT COUNT(*) INTO v_connected FROM players
  WHERE room_id = v_player.room_id AND is_connected = true;

  IF v_answered >= v_connected AND v_connected > 0 THEN
    PERFORM advance_survey_question(p_player_id, p_session_token, true);
  END IF;

  RETURN json_build_object('answered_count', v_answered, 'total', v_connected);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Shared interrogation round completion (manual end or timer expiry)
CREATE OR REPLACE FUNCTION complete_interrogation_round(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_host UUID;
BEGIN
  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'interrogation' THEN RETURN; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM interrogation_rounds
    WHERE room_id = p_room_id AND round_number = v_room.current_round
      AND suspect_player_id IS NOT NULL
  ) THEN
    RETURN;
  END IF;

  UPDATE interrogation_rounds SET completed_at = COALESCE(completed_at, now())
  WHERE room_id = p_room_id AND round_number = v_room.current_round;

  IF v_room.current_round IN (3, 6) THEN
    UPDATE rooms SET
      status = 'lie_detector',
      lie_detector_event = v_room.current_round / 3,
      lie_detector_step = 'vote_evidence',
      phase_ends_at = NULL,
      updated_at = now()
    WHERE id = p_room_id;
    RETURN;
  END IF;

  IF v_room.current_round >= 6 THEN
    UPDATE rooms SET status = 'suspect_vote', phase_ends_at = now() + interval '45 seconds', updated_at = now()
    WHERE id = p_room_id;
    RETURN;
  END IF;

  UPDATE rooms SET current_round = current_round + 1, phase_ends_at = NULL, updated_at = now()
  WHERE id = p_room_id;

  SELECT host_player_id INTO v_host FROM rooms WHERE id = p_room_id;
  IF v_host IS NOT NULL THEN
    PERFORM start_interrogation_round(v_host, (SELECT session_token FROM players WHERE id = v_host));
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION next_interrogation_round(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_interrogator UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'interrogation' THEN RETURN; END IF;

  SELECT interrogator_player_id INTO v_interrogator FROM interrogation_rounds
  WHERE room_id = v_player.room_id AND round_number = v_room.current_round;

  IF NOT v_player.is_host AND v_player.id != v_interrogator THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  PERFORM complete_interrogation_round(v_player.room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_lie_detector_evidence_options(p_room_id UUID)
RETURNS JSON AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_max_round INT;
  v_total INT;
BEGIN
  SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
  IF NOT FOUND THEN RETURN '[]'::json; END IF;

  v_max_round := CASE WHEN v_room.lie_detector_event = 1 THEN 3 ELSE 6 END;

  SELECT COUNT(*)::INT INTO v_total
  FROM players WHERE room_id = p_room_id AND is_connected = true;

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.evidence_order), '[]'::json)
    FROM (
      SELECT DISTINCT ON (e.id)
        e.id,
        e.room_id,
        e.evidence_order,
        e.evidence_text,
        e.question_id,
        q.question_text,
        e.answer_text,
        e.is_inspected,
        e.inspection_result,
        e.source_player_id,
        p.display_name AS source_player_name,
        count_matching_answers(e.room_id, e.question_id, e.answer_text) AS matching_count,
        v_total AS total_players,
        e.created_at
      FROM interrogation_rounds ir
      JOIN evidence e ON e.id = ir.evidence_id
      LEFT JOIN questions q ON q.id = e.question_id
      LEFT JOIN players p ON p.id = e.source_player_id
      WHERE ir.room_id = p_room_id
        AND ir.round_number <= v_max_round
        AND ir.suspect_player_id IS NOT NULL
      ORDER BY e.id, e.evidence_order
    ) t
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_lie_detector_result(
  p_room_id UUID,
  p_event_number INT,
  p_phase TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE v_rec lie_detector_results%ROWTYPE;
BEGIN
  IF p_phase IS NOT NULL THEN
    SELECT * INTO v_rec FROM lie_detector_results
    WHERE room_id = p_room_id AND event_number = p_event_number AND result_phase = p_phase;
  ELSE
    SELECT * INTO v_rec FROM lie_detector_results
    WHERE room_id = p_room_id AND event_number = p_event_number
    ORDER BY CASE result_phase WHEN 'player' THEN 2 ELSE 1 END DESC
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN RETURN NULL; END IF;

  RETURN json_build_object(
    'result_phase', v_rec.result_phase,
    'action_type', v_rec.action_type,
    'player_name', v_rec.player_name,
    'question_text', v_rec.question_text,
    'answer_text', v_rec.answer_text,
    'answer_verdict', v_rec.answer_verdict,
    'inspection_result', v_rec.inspection_result,
    'evidence_order', (SELECT evidence_order FROM evidence WHERE id = v_rec.target_evidence_id),
    'target_evidence_id', v_rec.target_evidence_id,
    'target_player_id', v_rec.target_player_id
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_lie_detector_state(p_room_id UUID)
RETURNS JSON AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_attached JSON;
  v_evidence_id UUID;
BEGIN
  SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
  IF NOT FOUND OR v_room.status != 'lie_detector' THEN RETURN NULL; END IF;

  SELECT target_evidence_id INTO v_evidence_id FROM lie_detector_results
  WHERE room_id = p_room_id AND event_number = v_room.lie_detector_event AND result_phase = 'evidence';

  IF v_evidence_id IS NOT NULL THEN
    SELECT json_build_object(
      'id', e.source_player_id,
      'name', p.display_name,
      'question_id', e.question_id,
      'question_text', q.question_text
    ) INTO v_attached
    FROM evidence e
    LEFT JOIN players p ON p.id = e.source_player_id
    LEFT JOIN questions q ON q.id = e.question_id
    WHERE e.id = v_evidence_id;
  END IF;

  RETURN json_build_object(
    'step', COALESCE(v_room.lie_detector_step, 'vote_evidence'),
    'event_number', v_room.lie_detector_event,
    'phase_ends_at', v_room.phase_ends_at,
    'evidence_options', get_lie_detector_evidence_options(p_room_id),
    'evidence_result', get_lie_detector_result(p_room_id, v_room.lie_detector_event, 'evidence'),
    'player_result', get_lie_detector_result(p_room_id, v_room.lie_detector_event, 'player'),
    'attached_player', v_attached
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
  v_attached_player UUID;
  v_attached_question UUID;
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
    IF p_action != 'check_answer' THEN
      RAISE EXCEPTION 'INVALID_VOTE';
    END IF;

    SELECT e.source_player_id, e.question_id
    INTO v_attached_player, v_attached_question
    FROM lie_detector_results lr
    JOIN evidence e ON e.id = lr.target_evidence_id
    WHERE lr.room_id = v_player.room_id
      AND lr.event_number = v_room.lie_detector_event
      AND lr.result_phase = 'evidence';

    IF v_attached_player IS NULL THEN
      RAISE EXCEPTION 'INVALID_STATE';
    END IF;

    IF p_target_player_id IS NULL OR p_target_player_id != v_attached_player THEN
      RAISE EXCEPTION 'INVALID_PLAYER';
    END IF;

    v_vote_phase := 'player';

    INSERT INTO lie_detector_votes (
      room_id, event_number, player_id, action_type, vote_phase,
      target_evidence_id, target_player_id, target_question_id
    )
    VALUES (
      v_player.room_id, v_room.lie_detector_event, p_player_id, p_action, v_vote_phase,
      NULL, v_attached_player, v_attached_question
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

    SELECT target_evidence_id INTO v_evidence_id FROM lie_detector_results
    WHERE room_id = p_room_id AND event_number = v_event AND result_phase = 'evidence';

    SELECT e.source_player_id, e.question_id
    INTO v_target_player, v_target_question
    FROM evidence e WHERE e.id = v_evidence_id;

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

CREATE OR REPLACE FUNCTION game_tick(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_status room_status;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;

  PERFORM pg_advisory_xact_lock(hashtext(v_player.room_id::text));

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_room.phase_ends_at IS NULL OR v_room.phase_ends_at > now() THEN RETURN; END IF;

  v_status := v_room.status;

  BEGIN
    CASE v_status
      WHEN 'survey' THEN
        PERFORM advance_survey_question(p_player_id, p_session_token, true);
      WHEN 'role_reveal' THEN
        PERFORM advance_from_role_reveal(p_player_id, p_session_token);
      WHEN 'crime_reveal' THEN
        PERFORM advance_from_crime_reveal(p_player_id, p_session_token);
      WHEN 'fake_evidence' THEN
        PERFORM generate_evidence_for_room(v_player.room_id);
      WHEN 'interrogation' THEN
        PERFORM complete_interrogation_round(v_player.room_id);
      WHEN 'lie_detector' THEN
        PERFORM try_resolve_lie_detector(v_player.room_id);
      WHEN 'suspect_vote' THEN
        PERFORM resolve_suspect_vote(v_player.room_id);
      WHEN 'final_vote', 'tie_breaker' THEN
        PERFORM resolve_final_vote(v_player.room_id, v_status = 'tie_breaker');
      ELSE
        NULL;
    END CASE;
  EXCEPTION
    WHEN unique_violation THEN NULL;
    WHEN serialization_failure THEN NULL;
    WHEN deadlock_detected THEN NULL;
  END;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.phase_ends_at IS NOT NULL
     AND v_room.phase_ends_at <= now()
     AND v_room.status = v_status THEN
    UPDATE rooms SET phase_ends_at = now() + interval '2 seconds', updated_at = now()
    WHERE id = v_player.room_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION play_again(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_prev UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  SELECT criminal_player_id INTO v_prev FROM rooms WHERE id = v_player.room_id;
  IF v_prev IS NULL THEN
    SELECT criminal_player_id INTO v_prev FROM game_results
    WHERE room_id = v_player.room_id ORDER BY created_at DESC LIMIT 1;
  END IF;

  DELETE FROM game_results WHERE room_id = v_player.room_id;
  DELETE FROM final_votes WHERE room_id = v_player.room_id;
  DELETE FROM suspect_votes WHERE room_id = v_player.room_id;
  DELETE FROM lie_detector_votes WHERE room_id = v_player.room_id;
  DELETE FROM lie_detector_results WHERE room_id = v_player.room_id;
  DELETE FROM interrogation_rounds WHERE room_id = v_player.room_id;
  DELETE FROM evidence WHERE room_id = v_player.room_id;
  DELETE FROM player_answers WHERE room_id = v_player.room_id;
  DELETE FROM game_questions WHERE room_id = v_player.room_id;

  UPDATE players SET role = 'unknown', fake_evidence_question_id = NULL WHERE room_id = v_player.room_id;

  UPDATE rooms SET
    status = 'lobby', current_question_index = 0, current_round = 0,
    current_crime_id = NULL, lie_detector_event = 0, lie_detector_step = NULL,
    phase_ends_at = NULL, tie_breaker_candidates = NULL, accused_player_id = NULL,
    criminal_player_id = NULL,
    previous_criminal_id = COALESCE(v_prev, previous_criminal_id), updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
