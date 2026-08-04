-- Fix 409 on advance_crime_to_evidence: restore safe evidence shuffle and error handling

CREATE OR REPLACE FUNCTION shuffle_evidence_order(p_room_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE evidence SET evidence_order = evidence_order + 1000 WHERE room_id = p_room_id;

  UPDATE evidence SET evidence_order = sub.new_order
  FROM (
    SELECT id, row_number() OVER (ORDER BY random()) AS new_order
    FROM evidence WHERE room_id = p_room_id
  ) sub
  WHERE evidence.id = sub.id AND evidence.room_id = p_room_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_evidence_for_room(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_criminal UUID;
  v_writer UUID;
  v_fake_q UUID;
  v_fake_text TEXT;
  v_q_type TEXT;
  v_q_text TEXT;
  v_order INT := 1;
  v_rec RECORD;
  v_evidence_text TEXT;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext(p_room_id::text || '_ev')) THEN
    RETURN;
  END IF;

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_room.status = 'evidence' THEN RETURN; END IF;
  IF v_room.status NOT IN ('crime_reveal', 'fake_evidence') THEN RETURN; END IF;

  IF (SELECT COUNT(*) FROM evidence WHERE room_id = p_room_id) >= 8 THEN
    UPDATE rooms SET status = 'evidence', phase_ends_at = now() + interval '15 seconds', updated_at = now()
    WHERE id = p_room_id;
    RETURN;
  END IF;

  v_criminal := get_room_criminal(p_room_id);
  IF v_criminal IS NULL THEN RETURN; END IF;

  SELECT gq.question_id INTO v_fake_q
  FROM game_questions gq WHERE gq.room_id = p_room_id ORDER BY random() LIMIT 1;

  IF v_fake_q IS NULL THEN
    SELECT id INTO v_fake_q FROM questions WHERE is_active = true ORDER BY random() LIMIT 1;
  END IF;

  SELECT id INTO v_writer FROM players
  WHERE room_id = p_room_id AND role = 'innocent' AND id != v_criminal
  ORDER BY random() LIMIT 1;

  IF v_writer IS NULL THEN
    SELECT id INTO v_writer FROM players
    WHERE room_id = p_room_id AND id != v_criminal
    ORDER BY random() LIMIT 1;
  END IF;

  SELECT pa.answer_text INTO v_fake_text
  FROM player_answers pa
  WHERE pa.room_id = p_room_id AND pa.question_id = v_fake_q AND pa.player_id != v_criminal
  ORDER BY random() LIMIT 1;

  IF v_fake_text IS NULL THEN
    SELECT pa.answer_text INTO v_fake_text FROM player_answers pa
    WHERE pa.room_id = p_room_id AND pa.question_id = v_fake_q ORDER BY random() LIMIT 1;
  END IF;

  IF v_fake_text IS NULL THEN v_fake_text := 'Something suspicious.'; END IF;

  UPDATE players SET fake_evidence_question_id = NULL, fake_evidence_answer = NULL WHERE room_id = p_room_id;
  IF v_writer IS NOT NULL AND v_fake_q IS NOT NULL THEN
    UPDATE players SET fake_evidence_question_id = v_fake_q WHERE id = v_writer;
  END IF;

  DELETE FROM evidence WHERE room_id = p_room_id;

  FOR v_rec IN
    SELECT gq.question_id, q.question_text, q.question_type::text AS qtype,
           COALESCE(pa_crime.answer_text, pa_any.answer_text, 'Unknown') AS answer_text
    FROM game_questions gq
    JOIN questions q ON q.id = gq.question_id
    LEFT JOIN player_answers pa_crime ON pa_crime.question_id = gq.question_id
      AND pa_crime.player_id = v_criminal AND pa_crime.room_id = p_room_id
    LEFT JOIN LATERAL (
      SELECT pa.answer_text FROM player_answers pa
      WHERE pa.room_id = p_room_id AND pa.question_id = gq.question_id
      LIMIT 1
    ) pa_any ON true
    WHERE gq.room_id = p_room_id AND (v_fake_q IS NULL OR gq.question_id != v_fake_q)
    ORDER BY gq.question_order
    LIMIT 7
  LOOP
    v_evidence_text := format_evidence(v_rec.question_text, v_rec.answer_text, v_rec.qtype);
    INSERT INTO evidence (room_id, evidence_order, question_id, evidence_text, answer_text, source_player_id, is_fake)
    VALUES (p_room_id, v_order, v_rec.question_id, v_evidence_text, v_rec.answer_text, v_criminal, false);
    v_order := v_order + 1;
  END LOOP;

  IF v_fake_q IS NOT NULL THEN
    SELECT question_text, question_type::text INTO v_q_text, v_q_type FROM questions WHERE id = v_fake_q;
    v_evidence_text := format_evidence(COALESCE(v_q_text, 'A survey question'), v_fake_text, COALESCE(v_q_type, 'short_answer'));
    INSERT INTO evidence (room_id, evidence_order, question_id, evidence_text, answer_text, source_player_id, is_fake)
    VALUES (p_room_id, v_order, v_fake_q, v_evidence_text, v_fake_text, v_writer, true);
  END IF;

  IF (SELECT COUNT(*) FROM evidence WHERE room_id = p_room_id) = 0 THEN
    INSERT INTO evidence (room_id, evidence_order, evidence_text, source_player_id, is_fake)
    VALUES (p_room_id, 1, 'The criminal left behind suspicious survey answers.', v_criminal, false);
  END IF;

  PERFORM shuffle_evidence_order(p_room_id);

  UPDATE rooms SET status = 'evidence', phase_ends_at = now() + interval '15 seconds', updated_at = now()
  WHERE id = p_room_id;
EXCEPTION
  WHEN unique_violation THEN
    IF (SELECT COUNT(*) FROM evidence WHERE room_id = p_room_id) > 0 THEN
      UPDATE rooms SET status = 'evidence', phase_ends_at = now() + interval '15 seconds', updated_at = now()
      WHERE id = p_room_id AND status IN ('crime_reveal', 'fake_evidence');
    END IF;
  WHEN serialization_failure THEN NULL;
  WHEN deadlock_detected THEN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION advance_crime_to_evidence(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  BEGIN
    PERFORM generate_evidence_for_room(v_player.room_id);
  EXCEPTION
    WHEN unique_violation THEN NULL;
    WHEN serialization_failure THEN NULL;
    WHEN deadlock_detected THEN NULL;
  END;

  -- Ensure room advances if evidence was created by a concurrent caller
  IF EXISTS (SELECT 1 FROM evidence WHERE room_id = v_player.room_id) THEN
    UPDATE rooms SET status = 'evidence', phase_ends_at = now() + interval '15 seconds', updated_at = now()
    WHERE id = v_player.room_id AND status = 'crime_reveal';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
