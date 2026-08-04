-- Fix lie detector reveal phase stuck when game_tick fails to advance

CREATE OR REPLACE FUNCTION finish_lie_detector_event(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_host UUID;
BEGIN
  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'lie_detector' THEN RETURN; END IF;

  SELECT host_player_id INTO v_host FROM rooms WHERE id = p_room_id;

  IF v_room.current_round >= 6 THEN
    UPDATE rooms SET
      status = 'suspect_vote',
      lie_detector_step = NULL,
      phase_ends_at = now() + interval '45 seconds',
      updated_at = now()
    WHERE id = p_room_id AND status = 'lie_detector';
    RETURN;
  END IF;

  UPDATE rooms SET
    status = 'interrogation',
    current_round = current_round + 1,
    lie_detector_step = NULL,
    phase_ends_at = NULL,
    updated_at = now()
  WHERE id = p_room_id AND status = 'lie_detector';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION try_resolve_lie_detector(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_voted INT;
  v_connected INT;
  v_step TEXT;
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
      WHERE id = p_room_id AND status = 'lie_detector';
      RETURN;
    END IF;

    PERFORM finish_lie_detector_event(p_room_id);
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
    WHERE id = p_room_id AND status = 'lie_detector';
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
    WHERE id = p_room_id AND status = 'lie_detector';
    RETURN;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION advance_lie_detector_if_ready(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;
  PERFORM try_resolve_lie_detector(v_player.room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION game_tick(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_status room_status;
  v_ld_reveal BOOLEAN;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;

  PERFORM pg_advisory_xact_lock(hashtext(v_player.room_id::text));

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  v_ld_reveal := v_room.status = 'lie_detector'
    AND COALESCE(v_room.lie_detector_step, '') IN ('reveal_evidence', 'reveal_player');

  IF v_room.phase_ends_at IS NULL THEN
    IF NOT v_ld_reveal THEN RETURN; END IF;
  ELSIF v_room.phase_ends_at > now() THEN
    RETURN;
  END IF;

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
    WHEN OTHERS THEN
      IF v_status = 'lie_detector' THEN
        IF COALESCE(v_room.lie_detector_step, '') = 'reveal_evidence' THEN
          UPDATE rooms SET lie_detector_step = 'vote_player', phase_ends_at = NULL, updated_at = now()
          WHERE id = v_player.room_id AND status = 'lie_detector';
        ELSIF COALESCE(v_room.lie_detector_step, '') = 'reveal_player' THEN
          PERFORM finish_lie_detector_event(v_player.room_id);
        END IF;
      END IF;
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
