-- Interrogator-only round advance; role reveal 5 seconds

CREATE OR REPLACE FUNCTION finish_survey(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_criminal_id UUID;
  v_prev UUID;
  v_candidates UUID[];
BEGIN
  SELECT previous_criminal_id INTO v_prev FROM rooms WHERE id = p_room_id;

  SELECT array_agg(id) INTO v_candidates FROM players
  WHERE room_id = p_room_id AND is_connected = true AND (v_prev IS NULL OR id != v_prev);

  IF v_candidates IS NULL OR array_length(v_candidates, 1) = 0 THEN
    SELECT id INTO v_criminal_id FROM players WHERE room_id = p_room_id AND is_connected = true ORDER BY random() LIMIT 1;
  ELSE
    v_criminal_id := v_candidates[1 + floor(random() * array_length(v_candidates, 1))::int];
  END IF;

  UPDATE players SET role = 'innocent' WHERE room_id = p_room_id;
  UPDATE players SET role = 'criminal' WHERE id = v_criminal_id;

  UPDATE rooms SET
    status = 'role_reveal',
    phase_ends_at = now() + interval '5 seconds',
    updated_at = now()
  WHERE id = p_room_id;
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

  IF v_player.id != v_interrogator THEN
    RAISE EXCEPTION 'NOT_INTERROGATOR';
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
