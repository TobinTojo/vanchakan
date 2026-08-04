-- Ensure role reveal and crime reveal auto-advance without requiring host
-- Safe to re-run

CREATE OR REPLACE FUNCTION advance_from_role_reveal(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_crime UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'role_reveal' OR v_room.phase_ends_at > now() THEN RETURN; END IF;

  SELECT id INTO v_crime FROM crimes WHERE is_active = true ORDER BY random() LIMIT 1;

  UPDATE rooms SET
    status = 'crime_reveal',
    current_crime_id = v_crime,
    phase_ends_at = now() + interval '6 seconds',
    updated_at = now()
  WHERE id = v_player.room_id AND status = 'role_reveal';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION advance_from_crime_reveal(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_writer UUID;
  v_fake_q UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'crime_reveal' OR v_room.phase_ends_at > now() THEN RETURN; END IF;

  SELECT id INTO v_writer FROM players
  WHERE room_id = v_player.room_id AND role = 'innocent' AND is_connected = true
  ORDER BY random() LIMIT 1;

  SELECT gq.question_id INTO v_fake_q FROM game_questions gq
  WHERE gq.room_id = v_player.room_id
  ORDER BY random() LIMIT 1;

  UPDATE players SET fake_evidence_question_id = v_fake_q, fake_evidence_answer = NULL WHERE id = v_writer;

  UPDATE rooms SET
    status = 'fake_evidence',
    phase_ends_at = now() + interval '30 seconds',
    updated_at = now()
  WHERE id = v_player.room_id AND status = 'crime_reveal';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
