-- Fix fake evidence 409 conflicts, timer auto-advance, and server time sync

ALTER TABLE players ADD COLUMN IF NOT EXISTS fake_evidence_answer TEXT;

-- Server time for synced client timers
CREATE OR REPLACE FUNCTION get_server_time()
RETURNS TIMESTAMPTZ AS $$
  SELECT now();
$$ LANGUAGE sql STABLE;

-- Submit fake evidence (store separately from survey answers to avoid conflicts)
CREATE OR REPLACE FUNCTION submit_fake_evidence(p_player_id UUID, p_session_token TEXT, p_answer_text TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  IF v_player.fake_evidence_question_id IS NULL THEN
    RAISE EXCEPTION 'NOT_FAKE_WRITER';
  END IF;

  UPDATE players
  SET fake_evidence_answer = trim(p_answer_text)
  WHERE id = p_player_id AND fake_evidence_question_id IS NOT NULL;

  PERFORM try_generate_evidence(v_player.room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Generate evidence with row lock to prevent race conditions (409 errors)
CREATE OR REPLACE FUNCTION try_generate_evidence(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_criminal UUID;
  v_writer UUID;
  v_fake_q UUID;
  v_fake_text TEXT;
  v_order INT := 1;
  v_rec RECORD;
  v_evidence_text TEXT;
BEGIN
  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'fake_evidence' THEN RETURN; END IF;

  SELECT id, fake_evidence_question_id, fake_evidence_answer
  INTO v_writer, v_fake_q, v_fake_text
  FROM players
  WHERE room_id = p_room_id AND fake_evidence_question_id IS NOT NULL
  LIMIT 1;

  IF v_room.phase_ends_at > now() THEN
    IF v_fake_text IS NULL OR trim(v_fake_text) = '' THEN
      RETURN;
    END IF;
  END IF;

  SELECT id INTO v_criminal FROM players WHERE room_id = p_room_id AND role = 'criminal';

  DELETE FROM evidence WHERE room_id = p_room_id;

  FOR v_rec IN
    SELECT gq.question_id, q.question_text, q.question_type, pa.answer_text
    FROM game_questions gq
    JOIN questions q ON q.id = gq.question_id
    JOIN player_answers pa ON pa.question_id = gq.question_id AND pa.player_id = v_criminal AND pa.room_id = p_room_id
    WHERE gq.room_id = p_room_id AND gq.question_id != COALESCE(v_fake_q, '00000000-0000-0000-0000-000000000000'::uuid)
    ORDER BY gq.question_order
    LIMIT 7
  LOOP
    v_evidence_text := format_evidence(v_rec.question_text, v_rec.answer_text, v_rec.question_type::text);
    INSERT INTO evidence (room_id, evidence_order, question_id, evidence_text, source_player_id, is_fake)
    VALUES (p_room_id, v_order, v_rec.question_id, v_evidence_text, v_criminal, false);
    v_order := v_order + 1;
  END LOOP;

  IF v_fake_text IS NULL OR trim(v_fake_text) = '' THEN
    SELECT pa.answer_text INTO v_fake_text
    FROM player_answers pa
    JOIN players p ON p.id = pa.player_id
    WHERE pa.room_id = p_room_id AND p.role = 'innocent' AND pa.question_id = v_fake_q
    ORDER BY random() LIMIT 1;
    IF v_fake_text IS NULL THEN v_fake_text := 'Unknown'; END IF;
  END IF;

  SELECT question_text INTO v_evidence_text FROM questions WHERE id = v_fake_q;
  v_evidence_text := format_evidence(
    v_evidence_text,
    v_fake_text,
    (SELECT question_type::text FROM questions WHERE id = v_fake_q)
  );

  INSERT INTO evidence (room_id, evidence_order, question_id, evidence_text, source_player_id, is_fake)
  VALUES (p_room_id, v_order, v_fake_q, v_evidence_text, v_writer, true);

  UPDATE evidence SET evidence_order = sub.new_order
  FROM (
    SELECT id, row_number() OVER (ORDER BY random()) AS new_order
    FROM evidence WHERE room_id = p_room_id
  ) sub WHERE evidence.id = sub.id;

  UPDATE rooms SET
    status = 'evidence',
    phase_ends_at = now() + interval '15 seconds',
    updated_at = now()
  WHERE id = p_room_id AND status = 'fake_evidence';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Auto-advance timed phases from ANY connected player (not just host)
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

-- Reset fake evidence answer on play again
CREATE OR REPLACE FUNCTION play_again(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_prev UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND OR NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  SELECT criminal_player_id INTO v_prev FROM game_results
  WHERE room_id = v_player.room_id ORDER BY created_at DESC LIMIT 1;

  DELETE FROM final_votes WHERE room_id = v_player.room_id;
  DELETE FROM suspect_votes WHERE room_id = v_player.room_id;
  DELETE FROM lie_detector_votes WHERE room_id = v_player.room_id;
  DELETE FROM interrogation_rounds WHERE room_id = v_player.room_id;
  DELETE FROM evidence WHERE room_id = v_player.room_id;
  DELETE FROM player_answers WHERE room_id = v_player.room_id;
  DELETE FROM game_questions WHERE room_id = v_player.room_id;

  UPDATE players SET
    role = 'unknown',
    fake_evidence_question_id = NULL,
    fake_evidence_answer = NULL
  WHERE room_id = v_player.room_id;

  UPDATE rooms SET
    status = 'lobby', current_question_index = 0, current_round = 0,
    current_crime_id = NULL, lie_detector_event = 0, phase_ends_at = NULL,
    tie_breaker_candidates = NULL, accused_player_id = NULL,
    previous_criminal_id = COALESCE(v_prev, previous_criminal_id), updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
