-- Randomize which 6 of 8 evidence cards appear during interrogation (fair round assignment)

CREATE OR REPLACE FUNCTION start_interrogation(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_players UUID[];
  v_evidence_ids UUID[];
  v_round INT;
  v_round_count INT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND OR NOT v_player.is_host THEN RETURN; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'evidence' THEN RETURN; END IF;

  SELECT array_agg(id ORDER BY joined_at) INTO v_players
  FROM players WHERE room_id = v_player.room_id AND is_connected = true;

  -- Pick up to 6 evidence cards in random order (8 total, 6 rounds)
  SELECT array_agg(id) INTO v_evidence_ids
  FROM (
    SELECT id
    FROM evidence
    WHERE room_id = v_player.room_id
    ORDER BY random()
    LIMIT 6
  ) picked;

  IF v_players IS NULL OR array_length(v_players, 1) < 2 THEN
    RAISE EXCEPTION 'NOT_ENOUGH_PLAYERS';
  END IF;

  v_round_count := COALESCE(array_length(v_evidence_ids, 1), 0);
  IF v_round_count = 0 THEN RETURN; END IF;

  DELETE FROM interrogation_rounds WHERE room_id = v_player.room_id;

  FOR v_round IN 1..v_round_count LOOP
    INSERT INTO interrogation_rounds (
      room_id, round_number, evidence_id, interrogator_player_id, suspect_player_id
    ) VALUES (
      v_player.room_id,
      v_round,
      v_evidence_ids[v_round],
      v_players[1 + ((v_round - 1) % array_length(v_players, 1))],
      NULL
    );
  END LOOP;

  UPDATE rooms SET status = 'interrogation', current_round = 1, phase_ends_at = NULL, updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
