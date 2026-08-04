-- Host-only play again, interrogator can end round, lie detector check_answer reveal

CREATE TABLE IF NOT EXISTS lie_detector_results (
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  event_number INT NOT NULL,
  action_type lie_detector_action NOT NULL,
  target_evidence_id UUID REFERENCES evidence(id),
  target_player_id UUID REFERENCES players(id),
  target_question_id UUID REFERENCES questions(id),
  player_name TEXT,
  question_text TEXT,
  answer_text TEXT,
  inspection_result TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (room_id, event_number)
);

ALTER TABLE lie_detector_results ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ldr_read" ON lie_detector_results FOR SELECT USING (true);

CREATE OR REPLACE FUNCTION get_lie_detector_result(p_room_id UUID, p_event_number INT)
RETURNS JSON AS $$
DECLARE v_rec lie_detector_results%ROWTYPE;
BEGIN
  SELECT * INTO v_rec FROM lie_detector_results
  WHERE room_id = p_room_id AND event_number = p_event_number;
  IF NOT FOUND THEN RETURN NULL; END IF;

  RETURN json_build_object(
    'action_type', v_rec.action_type,
    'player_name', v_rec.player_name,
    'question_text', v_rec.question_text,
    'answer_text', v_rec.answer_text,
    'inspection_result', v_rec.inspection_result,
    'evidence_order', (SELECT evidence_order FROM evidence WHERE id = v_rec.target_evidence_id)
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION try_resolve_lie_detector(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_voted INT;
  v_connected INT;
  v_action lie_detector_action;
  v_host UUID;
  v_evidence_id UUID;
  v_target_player UUID;
  v_target_question UUID;
  v_player_name TEXT;
  v_question_text TEXT;
  v_answer_text TEXT;
  v_inspection TEXT;
  v_event INT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_ld'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'lie_detector' THEN RETURN; END IF;

  v_event := v_room.lie_detector_event;

  -- Result already computed: advance once reveal timer expires
  IF EXISTS (SELECT 1 FROM lie_detector_results WHERE room_id = p_room_id AND event_number = v_event) THEN
    IF v_room.phase_ends_at IS NOT NULL AND v_room.phase_ends_at > now() THEN RETURN; END IF;

    SELECT host_player_id INTO v_host FROM rooms WHERE id = p_room_id;

    IF v_room.current_round >= 6 THEN
      UPDATE rooms SET status = 'suspect_vote', phase_ends_at = now() + interval '45 seconds', updated_at = now()
      WHERE id = p_room_id AND status = 'lie_detector';
    ELSE
      UPDATE rooms SET status = 'interrogation', current_round = current_round + 1,
        phase_ends_at = NULL, updated_at = now()
      WHERE id = p_room_id AND status = 'lie_detector';

      IF FOUND AND v_host IS NOT NULL THEN
        PERFORM start_interrogation_round(v_host, (SELECT session_token FROM players WHERE id = v_host));
      END IF;
    END IF;
    RETURN;
  END IF;

  SELECT COUNT(*) INTO v_voted FROM lie_detector_votes
  WHERE room_id = p_room_id AND event_number = v_event;
  SELECT COUNT(*) INTO v_connected FROM players WHERE room_id = p_room_id AND is_connected = true;

  IF v_voted < v_connected AND v_room.phase_ends_at > now() THEN RETURN; END IF;

  SELECT action_type INTO v_action FROM lie_detector_votes
  WHERE room_id = p_room_id AND event_number = v_event
  GROUP BY action_type ORDER BY COUNT(*) DESC LIMIT 1;

  IF v_action IS NULL THEN
    UPDATE rooms SET phase_ends_at = now() + interval '12 seconds', updated_at = now() WHERE id = p_room_id;
    RETURN;
  END IF;

  IF v_action = 'inspect_evidence' THEN
    SELECT target_evidence_id INTO v_evidence_id FROM lie_detector_votes
    WHERE room_id = p_room_id AND event_number = v_event AND action_type = 'inspect_evidence'
    GROUP BY target_evidence_id ORDER BY COUNT(*) DESC LIMIT 1;

    IF v_evidence_id IS NOT NULL THEN
      UPDATE evidence SET is_inspected = true,
        inspection_result = CASE WHEN is_fake THEN 'Fake Evidence' ELSE 'Genuine Evidence' END
      WHERE id = v_evidence_id
      RETURNING inspection_result INTO v_inspection;

      INSERT INTO lie_detector_results (room_id, event_number, action_type, target_evidence_id, inspection_result)
      VALUES (p_room_id, v_event, 'inspect_evidence', v_evidence_id, v_inspection);
    END IF;

  ELSIF v_action = 'check_answer' THEN
    SELECT ld.target_player_id, ld.target_question_id INTO v_target_player, v_target_question
    FROM lie_detector_votes ld
    WHERE ld.room_id = p_room_id AND ld.event_number = v_event AND ld.action_type = 'check_answer'
    GROUP BY ld.target_player_id, ld.target_question_id
    ORDER BY COUNT(*) DESC LIMIT 1;

    IF v_target_player IS NOT NULL AND v_target_question IS NOT NULL THEN
      SELECT p.display_name, q.question_text, pa.answer_text
      INTO v_player_name, v_question_text, v_answer_text
      FROM players p
      JOIN questions q ON q.id = v_target_question
      LEFT JOIN player_answers pa ON pa.player_id = v_target_player
        AND pa.question_id = v_target_question AND pa.room_id = p_room_id
      WHERE p.id = v_target_player;

      INSERT INTO lie_detector_results (
        room_id, event_number, action_type, target_player_id, target_question_id,
        player_name, question_text, answer_text
      ) VALUES (
        p_room_id, v_event, 'check_answer', v_target_player, v_target_question,
        v_player_name, v_question_text, COALESCE(v_answer_text, 'No answer')
      );
    END IF;
  END IF;

  -- Pause for reveal before advancing
  UPDATE rooms SET phase_ends_at = now() + interval '12 seconds', updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Host OR current interrogator can advance the round
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

  UPDATE interrogation_rounds SET completed_at = now()
  WHERE room_id = v_player.room_id AND round_number = v_room.current_round;

  IF v_room.current_round IN (3, 6) THEN
    UPDATE rooms SET status = 'lie_detector', lie_detector_event = v_room.current_round / 3,
      phase_ends_at = now() + interval '30 seconds', updated_at = now()
    WHERE id = v_player.room_id;
    RETURN;
  END IF;

  IF v_room.current_round >= 6 THEN
    UPDATE rooms SET status = 'suspect_vote', phase_ends_at = now() + interval '45 seconds', updated_at = now()
    WHERE id = v_player.room_id;
    RETURN;
  END IF;

  UPDATE rooms SET current_round = current_round + 1, phase_ends_at = NULL, updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Host-only play again
CREATE OR REPLACE FUNCTION play_again(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_prev UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  SELECT criminal_player_id INTO v_prev FROM game_results
  WHERE room_id = v_player.room_id ORDER BY created_at DESC LIMIT 1;

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
    current_crime_id = NULL, lie_detector_event = 0, phase_ends_at = NULL,
    tie_breaker_candidates = NULL, accused_player_id = NULL,
    previous_criminal_id = COALESCE(v_prev, previous_criminal_id), updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE lie_detector_results;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;