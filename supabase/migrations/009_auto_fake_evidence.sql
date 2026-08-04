-- Auto-generate fake evidence (no player input). Skip fake_evidence waiting phase.

CREATE OR REPLACE FUNCTION generate_evidence_for_room(p_room_id UUID)
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
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_ev'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  IF v_room.status = 'evidence' THEN RETURN; END IF;

  IF v_room.status NOT IN ('crime_reveal', 'fake_evidence') THEN RETURN; END IF;

  IF (SELECT COUNT(*) FROM evidence WHERE room_id = p_room_id) >= 8 THEN
    UPDATE rooms SET status = 'evidence', phase_ends_at = now() + interval '15 seconds', updated_at = now()
    WHERE id = p_room_id;
    RETURN;
  END IF;

  SELECT id INTO v_criminal FROM players WHERE room_id = p_room_id AND role = 'criminal';

  -- Pick a random survey question to use as the fake evidence source
  SELECT gq.question_id INTO v_fake_q
  FROM game_questions gq
  WHERE gq.room_id = p_room_id
  ORDER BY random() LIMIT 1;

  -- Random innocent is credited as the fake evidence writer in results
  SELECT id INTO v_writer FROM players
  WHERE room_id = p_room_id AND role = 'innocent'
  ORDER BY random() LIMIT 1;

  -- Auto-pick a believable fake answer from any non-criminal player's survey response
  SELECT pa.answer_text INTO v_fake_text
  FROM player_answers pa
  JOIN players p ON p.id = pa.player_id
  WHERE pa.room_id = p_room_id
    AND pa.question_id = v_fake_q
    AND p.id != v_criminal
  ORDER BY random() LIMIT 1;

  IF v_fake_text IS NULL THEN
    SELECT pa.answer_text INTO v_fake_text
    FROM player_answers pa
    WHERE pa.room_id = p_room_id AND pa.question_id = v_fake_q
    ORDER BY random() LIMIT 1;
  END IF;

  IF v_fake_text IS NULL THEN v_fake_text := 'No answer'; END IF;

  UPDATE players SET fake_evidence_question_id = NULL, fake_evidence_answer = NULL
  WHERE room_id = p_room_id;

  IF v_writer IS NOT NULL THEN
    UPDATE players SET fake_evidence_question_id = v_fake_q WHERE id = v_writer;
  END IF;

  DELETE FROM evidence WHERE room_id = p_room_id;

  FOR v_rec IN
    SELECT gq.question_id, q.question_text, q.question_type, pa.answer_text
    FROM game_questions gq
    JOIN questions q ON q.id = gq.question_id
    JOIN player_answers pa ON pa.question_id = gq.question_id
      AND pa.player_id = v_criminal AND pa.room_id = p_room_id
    WHERE gq.room_id = p_room_id AND gq.question_id != v_fake_q
    ORDER BY gq.question_order
    LIMIT 7
  LOOP
    v_evidence_text := format_evidence(v_rec.question_text, v_rec.answer_text, v_rec.question_type::text);
    INSERT INTO evidence (room_id, evidence_order, question_id, evidence_text, source_player_id, is_fake)
    VALUES (p_room_id, v_order, v_rec.question_id, v_evidence_text, v_criminal, false);
    v_order := v_order + 1;
  END LOOP;

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
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- After crime reveal, immediately generate all evidence (no player fake-evidence step)
CREATE OR REPLACE FUNCTION advance_from_crime_reveal(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'crime_reveal' OR v_room.phase_ends_at > now() THEN RETURN; END IF;

  PERFORM generate_evidence_for_room(v_player.room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Legacy submit still works but is no longer needed
CREATE OR REPLACE FUNCTION submit_fake_evidence(p_player_id UUID, p_session_token TEXT, p_answer_text TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;
  PERFORM generate_evidence_for_room(v_player.room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION try_generate_evidence(p_room_id UUID)
RETURNS VOID AS $$
BEGIN
  PERFORM generate_evidence_for_room(p_room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update game_tick fake_evidence recovery
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
        PERFORM advance_survey_question(p_player_id, p_session_token);
      WHEN 'role_reveal' THEN
        PERFORM advance_from_role_reveal(p_player_id, p_session_token);
      WHEN 'crime_reveal' THEN
        PERFORM advance_from_crime_reveal(p_player_id, p_session_token);
      WHEN 'fake_evidence' THEN
        PERFORM generate_evidence_for_room(v_player.room_id);
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
