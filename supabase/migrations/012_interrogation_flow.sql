-- Suspectives-style interrogation: interrogator picks target, answer match counts, no typed defense

ALTER TABLE evidence ADD COLUMN IF NOT EXISTS answer_text TEXT;
ALTER TABLE interrogation_rounds ADD COLUMN IF NOT EXISTS interrogator_player_id UUID REFERENCES players(id);
ALTER TABLE interrogation_rounds ALTER COLUMN suspect_player_id DROP NOT NULL;

-- Backfill answer_text from criminal/source answers where possible
UPDATE evidence e
SET answer_text = pa.answer_text
FROM player_answers pa
WHERE e.answer_text IS NULL
  AND e.question_id IS NOT NULL
  AND e.room_id = pa.room_id
  AND e.question_id = pa.question_id
  AND pa.player_id = e.source_player_id;

CREATE OR REPLACE FUNCTION count_matching_answers(
  p_room_id UUID,
  p_question_id UUID,
  p_answer_text TEXT
)
RETURNS INT AS $$
  SELECT COUNT(*)::INT
  FROM player_answers pa
  JOIN players p ON p.id = pa.player_id AND p.is_connected = true
  WHERE pa.room_id = p_room_id
    AND pa.question_id = p_question_id
    AND lower(trim(pa.answer_text)) = lower(trim(COALESCE(p_answer_text, '')));
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION get_evidence_with_stats(p_room_id UUID)
RETURNS JSON AS $$
DECLARE
  v_total INT;
BEGIN
  SELECT COUNT(*)::INT INTO v_total
  FROM players WHERE room_id = p_room_id AND is_connected = true;

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.evidence_order), '[]'::json)
    FROM (
      SELECT
        e.id,
        e.room_id,
        e.evidence_order,
        e.evidence_text,
        e.question_id,
        e.answer_text,
        e.is_inspected,
        e.inspection_result,
        e.created_at,
        count_matching_answers(e.room_id, e.question_id, e.answer_text) AS matching_count,
        v_total AS total_players
      FROM evidence e
      WHERE e.room_id = p_room_id
      ORDER BY e.evidence_order
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Store answer_text when generating evidence
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

  SELECT id INTO v_criminal FROM players WHERE room_id = p_room_id AND role = 'criminal' LIMIT 1;

  SELECT gq.question_id INTO v_fake_q
  FROM game_questions gq WHERE gq.room_id = p_room_id ORDER BY random() LIMIT 1;

  IF v_fake_q IS NULL THEN
    SELECT id INTO v_fake_q FROM questions WHERE is_active = true ORDER BY random() LIMIT 1;
  END IF;

  SELECT id INTO v_writer FROM players
  WHERE room_id = p_room_id AND role = 'innocent' ORDER BY random() LIMIT 1;

  IF v_writer IS NULL THEN
    SELECT id INTO v_writer FROM players
    WHERE room_id = p_room_id AND id != COALESCE(v_criminal, '00000000-0000-0000-0000-000000000000'::uuid)
    ORDER BY random() LIMIT 1;
  END IF;

  SELECT pa.answer_text INTO v_fake_text
  FROM player_answers pa
  WHERE pa.room_id = p_room_id AND pa.question_id = v_fake_q AND pa.player_id != COALESCE(v_criminal, pa.player_id)
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
      ORDER BY random() LIMIT 1
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
    INSERT INTO evidence (room_id, evidence_order, evidence_text, answer_text, source_player_id, is_fake)
    VALUES (p_room_id, 1, 'The criminal left behind suspicious survey answers.', 'Unknown', v_criminal, false);
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

-- One evidence per round; interrogator assigned; suspect chosen by interrogator
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

  SELECT array_agg(id ORDER BY evidence_order) INTO v_evidence_ids
  FROM evidence WHERE room_id = v_player.room_id;

  IF v_players IS NULL OR array_length(v_players, 1) < 2 THEN
    RAISE EXCEPTION 'NOT_ENOUGH_PLAYERS';
  END IF;

  v_round_count := LEAST(6, COALESCE(array_length(v_evidence_ids, 1), 0));
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

CREATE OR REPLACE FUNCTION select_interrogation_target(
  p_player_id UUID,
  p_session_token TEXT,
  p_target_player_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_round interrogation_rounds%ROWTYPE;
  v_target players%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'interrogation' THEN RETURN; END IF;

  SELECT * INTO v_round FROM interrogation_rounds
  WHERE room_id = v_player.room_id AND round_number = v_room.current_round FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
  IF v_round.interrogator_player_id != p_player_id THEN RAISE EXCEPTION 'NOT_INTERROGATOR'; END IF;
  IF v_round.suspect_player_id IS NOT NULL THEN RETURN; END IF;

  SELECT * INTO v_target FROM players
  WHERE id = p_target_player_id AND room_id = v_player.room_id AND is_connected = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_TARGET'; END IF;
  IF p_target_player_id = p_player_id THEN RAISE EXCEPTION 'CANNOT_INTERROGATE_SELF'; END IF;

  UPDATE interrogation_rounds SET suspect_player_id = p_target_player_id
  WHERE id = v_round.id;

  PERFORM start_interrogation_round(p_player_id, p_session_token);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION start_interrogation_round(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_round interrogation_rounds%ROWTYPE;
  v_now TIMESTAMPTZ := now();
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'interrogation' THEN RETURN; END IF;

  SELECT * INTO v_round FROM interrogation_rounds
  WHERE room_id = v_player.room_id AND round_number = v_room.current_round;

  IF NOT FOUND OR v_round.suspect_player_id IS NULL THEN RETURN; END IF;

  UPDATE interrogation_rounds SET started_at = v_now, ends_at = v_now + interval '60 seconds', completed_at = NULL
  WHERE id = v_round.id;

  UPDATE rooms SET phase_ends_at = v_now + interval '60 seconds', updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION next_interrogation_round(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_room rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND OR NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'interrogation' THEN RETURN; END IF;

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
