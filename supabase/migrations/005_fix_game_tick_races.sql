-- Fix game_tick 409 race conditions from concurrent clients

-- Safe game tick with advisory lock and conflict handling
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
        PERFORM try_generate_evidence(v_player.room_id);
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
    WHEN unique_violation THEN
      NULL;
    WHEN serialization_failure THEN
      NULL;
    WHEN deadlock_detected THEN
      NULL;
  END;

  -- Re-read room; if timer expired but phase did not change, nudge retry
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.phase_ends_at IS NOT NULL
     AND v_room.phase_ends_at <= now()
     AND v_room.status = v_status THEN
    UPDATE rooms SET phase_ends_at = now() + interval '2 seconds', updated_at = now()
    WHERE id = v_player.room_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Idempotent survey advance
CREATE OR REPLACE FUNCTION advance_survey_question(p_player_id UUID, p_session_token TEXT)
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

  IF v_gq.started_at IS NOT NULL AND v_gq.ends_at > v_now THEN RETURN; END IF;

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
    IF v_gq.started_at IS NOT NULL AND v_gq.ends_at > v_now THEN RETURN; END IF;
  END IF;

  UPDATE game_questions SET started_at = v_now, ends_at = v_now + interval '30 seconds'
  WHERE id = v_gq.id AND started_at IS NULL;

  UPDATE rooms SET phase_ends_at = v_now + interval '30 seconds', updated_at = now()
  WHERE id = v_player.room_id AND status = 'survey';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Idempotent lie detector resolve
CREATE OR REPLACE FUNCTION try_resolve_lie_detector(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_voted INT;
  v_connected INT;
  v_action lie_detector_action;
  v_host UUID;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_ld'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'lie_detector' THEN RETURN; END IF;

  SELECT COUNT(*) INTO v_voted FROM lie_detector_votes
  WHERE room_id = p_room_id AND event_number = v_room.lie_detector_event;
  SELECT COUNT(*) INTO v_connected FROM players WHERE room_id = p_room_id AND is_connected = true;

  IF v_voted < v_connected AND v_room.phase_ends_at > now() THEN RETURN; END IF;

  SELECT action_type INTO v_action FROM lie_detector_votes
  WHERE room_id = p_room_id AND event_number = v_room.lie_detector_event
  GROUP BY action_type ORDER BY COUNT(*) DESC LIMIT 1;

  IF v_action = 'inspect_evidence' THEN
    UPDATE evidence SET is_inspected = true,
      inspection_result = CASE WHEN is_fake THEN 'Fake Evidence' ELSE 'Genuine Evidence' END
    WHERE id = (
      SELECT target_evidence_id FROM lie_detector_votes
      WHERE room_id = p_room_id AND event_number = v_room.lie_detector_event AND action_type = 'inspect_evidence'
      GROUP BY target_evidence_id ORDER BY COUNT(*) DESC LIMIT 1
    );
  END IF;

  SELECT host_player_id INTO v_host FROM rooms WHERE id = p_room_id;

  IF v_room.current_round >= 6 THEN
    UPDATE rooms SET status = 'suspect_vote', phase_ends_at = now() + interval '45 seconds', updated_at = now()
    WHERE id = p_room_id AND status = 'lie_detector';
  ELSE
    UPDATE rooms SET status = 'interrogation', current_round = current_round + 1,
      phase_ends_at = now() + interval '60 seconds', updated_at = now()
    WHERE id = p_room_id AND status = 'lie_detector';

    IF FOUND AND v_host IS NOT NULL THEN
      PERFORM start_interrogation_round(v_host, (SELECT session_token FROM players WHERE id = v_host));
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Idempotent suspect vote resolve
CREATE OR REPLACE FUNCTION resolve_suspect_vote(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_finalists UUID[];
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_sv'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'suspect_vote' THEN RETURN; END IF;

  SELECT array_agg(p.id) INTO v_finalists FROM players p
  WHERE p.room_id = p_room_id AND p.is_connected = true
  AND EXISTS (SELECT 1 FROM suspect_votes sv WHERE sv.room_id = p_room_id AND sv.suspect_player_id = p.id);

  IF v_finalists IS NULL OR array_length(v_finalists, 1) <= 1 THEN
    SELECT array_agg(id) INTO v_finalists FROM players WHERE room_id = p_room_id AND is_connected = true;
  END IF;

  UPDATE rooms SET status = 'final_vote', phase_ends_at = now() + interval '30 seconds', updated_at = now()
  WHERE id = p_room_id AND status = 'suspect_vote';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Idempotent final vote resolve
CREATE OR REPLACE FUNCTION resolve_final_vote(p_room_id UUID, p_is_tie_breaker BOOLEAN DEFAULT false)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_accused UUID;
  v_top_count INT;
  v_tied UUID[];
  v_criminal UUID;
  v_writer UUID;
  v_winner TEXT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_fv'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_room.status NOT IN ('final_vote', 'tie_breaker') THEN RETURN; END IF;
  IF p_is_tie_breaker AND v_room.status != 'tie_breaker' THEN RETURN; END IF;
  IF NOT p_is_tie_breaker AND v_room.status != 'final_vote' THEN RETURN; END IF;

  SELECT suspect_player_id, COUNT(*) AS cnt INTO v_accused, v_top_count
  FROM final_votes WHERE room_id = p_room_id AND is_tie_breaker = p_is_tie_breaker
  GROUP BY suspect_player_id ORDER BY cnt DESC LIMIT 1;

  IF v_accused IS NULL THEN RETURN; END IF;

  SELECT array_agg(suspect_player_id) INTO v_tied FROM (
    SELECT suspect_player_id, COUNT(*) AS cnt FROM final_votes
    WHERE room_id = p_room_id AND is_tie_breaker = p_is_tie_breaker
    GROUP BY suspect_player_id HAVING COUNT(*) = v_top_count
  ) sub;

  IF array_length(v_tied, 1) > 1 AND NOT p_is_tie_breaker THEN
    UPDATE rooms SET status = 'tie_breaker', tie_breaker_candidates = v_tied,
      phase_ends_at = now() + interval '20 seconds', updated_at = now()
    WHERE id = p_room_id AND status = 'final_vote';
    RETURN;
  END IF;

  IF array_length(v_tied, 1) > 1 THEN
    v_accused := v_tied[1 + floor(random() * array_length(v_tied, 1))::int];
  END IF;

  SELECT id INTO v_criminal FROM players WHERE room_id = p_room_id AND role = 'criminal';
  SELECT source_player_id INTO v_writer FROM evidence WHERE room_id = p_room_id AND is_fake = true LIMIT 1;

  IF v_accused = v_criminal THEN v_winner := 'detectives'; ELSE v_winner := 'criminal'; END IF;

  IF NOT EXISTS (SELECT 1 FROM game_results WHERE room_id = p_room_id) THEN
    INSERT INTO game_results (room_id, criminal_player_id, accused_player_id, fake_evidence_writer_id, winning_side)
    VALUES (p_room_id, v_criminal, v_accused, v_writer, v_winner);
  END IF;

  UPDATE rooms SET status = 'results', accused_player_id = v_accused,
    previous_criminal_id = v_criminal, phase_ends_at = NULL, updated_at = now()
  WHERE id = p_room_id AND status IN ('final_vote', 'tie_breaker');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure fake evidence column exists (safe if 004 already ran)
ALTER TABLE players ADD COLUMN IF NOT EXISTS fake_evidence_answer TEXT;

-- Safer submit fake evidence
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

  BEGIN
    PERFORM try_generate_evidence(v_player.room_id);
  EXCEPTION
    WHEN unique_violation THEN NULL;
    WHEN serialization_failure THEN NULL;
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recovery: if evidence exists but still in fake_evidence phase, advance
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
  v_count INT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_ev'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'fake_evidence' THEN RETURN; END IF;

  SELECT COUNT(*) INTO v_count FROM evidence WHERE room_id = p_room_id;
  IF v_count >= 8 THEN
    UPDATE rooms SET status = 'evidence', phase_ends_at = now() + interval '15 seconds', updated_at = now()
    WHERE id = p_room_id AND status = 'fake_evidence';
    RETURN;
  END IF;

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
