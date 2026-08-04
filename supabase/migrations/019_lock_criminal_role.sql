-- Lock criminal assignment so it cannot change after role reveal; fix results accuracy

ALTER TABLE rooms ADD COLUMN IF NOT EXISTS criminal_player_id UUID REFERENCES players(id);

CREATE OR REPLACE FUNCTION get_room_criminal(p_room_id UUID)
RETURNS UUID AS $$
DECLARE v_criminal UUID;
BEGIN
  SELECT criminal_player_id INTO v_criminal FROM rooms WHERE id = p_room_id;
  IF v_criminal IS NOT NULL THEN RETURN v_criminal; END IF;

  SELECT id INTO v_criminal FROM players
  WHERE room_id = p_room_id AND role = 'criminal'
  LIMIT 1;

  RETURN v_criminal;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION finish_survey(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_criminal_id UUID;
  v_prev UUID;
  v_candidates UUID[];
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_finish_survey'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_room.status != 'survey' THEN RETURN; END IF;

  IF v_room.criminal_player_id IS NOT NULL THEN
    UPDATE rooms SET status = 'role_reveal', phase_ends_at = NULL, updated_at = now()
    WHERE id = p_room_id AND status = 'survey';
    RETURN;
  END IF;

  SELECT previous_criminal_id INTO v_prev FROM rooms WHERE id = p_room_id;

  SELECT array_agg(id) INTO v_candidates FROM players
  WHERE room_id = p_room_id AND is_connected = true AND (v_prev IS NULL OR id != v_prev);

  IF v_candidates IS NULL OR array_length(v_candidates, 1) = 0 THEN
    SELECT id INTO v_criminal_id FROM players
    WHERE room_id = p_room_id AND is_connected = true ORDER BY random() LIMIT 1;
  ELSE
    v_criminal_id := v_candidates[1 + floor(random() * array_length(v_candidates, 1))::int];
  END IF;

  UPDATE players SET role = 'innocent' WHERE room_id = p_room_id;
  UPDATE players SET role = 'criminal' WHERE id = v_criminal_id;

  UPDATE rooms SET
    status = 'role_reveal',
    criminal_player_id = v_criminal_id,
    phase_ends_at = NULL,
    updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

  v_criminal := get_room_criminal(p_room_id);
  IF v_criminal IS NULL THEN RETURN; END IF;

  SELECT gq.question_id INTO v_fake_q
  FROM game_questions gq WHERE gq.room_id = p_room_id ORDER BY random() LIMIT 1;

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
    WHERE pa.room_id = p_room_id AND pa.player_id != v_criminal
    ORDER BY random() LIMIT 1;
  END IF;

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
    WHERE gq.room_id = p_room_id
    ORDER BY gq.question_order
  LOOP
    v_evidence_text := format_evidence(v_rec.question_text, v_rec.answer_text, v_rec.qtype);
    INSERT INTO evidence (room_id, evidence_order, question_id, evidence_text, answer_text, source_player_id, is_fake)
    VALUES (p_room_id, v_order, v_rec.question_id, v_evidence_text, v_rec.answer_text, v_criminal, false);
    v_order := v_order + 1;
  END LOOP;

  IF v_fake_q IS NOT NULL AND v_fake_text IS NOT NULL AND v_writer IS NOT NULL THEN
    INSERT INTO evidence (room_id, evidence_order, question_id, evidence_text, answer_text, source_player_id, is_fake)
    SELECT p_room_id, v_order, v_fake_q,
      format_evidence(q.question_text, v_fake_text, q.question_type::text),
      v_fake_text, v_writer, true
    FROM questions q WHERE q.id = v_fake_q;
  END IF;

  UPDATE evidence SET evidence_order = sub.new_order
  FROM (
    SELECT id, row_number() OVER (ORDER BY random()) AS new_order
    FROM evidence WHERE room_id = p_room_id
  ) sub WHERE evidence.id = sub.id;

  UPDATE rooms SET status = 'evidence', phase_ends_at = now() + interval '15 seconds', updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
  v_voted INT;
  v_connected INT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_fv'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_room.status NOT IN ('final_vote', 'tie_breaker') THEN RETURN; END IF;
  IF p_is_tie_breaker AND v_room.status != 'tie_breaker' THEN RETURN; END IF;
  IF NOT p_is_tie_breaker AND v_room.status != 'final_vote' THEN RETURN; END IF;

  v_criminal := get_room_criminal(p_room_id);

  IF EXISTS (SELECT 1 FROM game_results WHERE room_id = p_room_id) THEN
    UPDATE rooms SET status = 'results', phase_ends_at = NULL, updated_at = now()
    WHERE id = p_room_id AND status IN ('final_vote', 'tie_breaker');
    RETURN;
  END IF;

  SELECT COUNT(DISTINCT voter_player_id) INTO v_voted FROM final_votes
  WHERE room_id = p_room_id AND is_tie_breaker = p_is_tie_breaker;
  SELECT COUNT(*) INTO v_connected FROM players WHERE room_id = p_room_id AND is_connected = true;

  IF v_voted < v_connected AND v_room.phase_ends_at IS NOT NULL AND v_room.phase_ends_at > now() THEN
    RETURN;
  END IF;

  SELECT suspect_player_id, COUNT(*) AS cnt INTO v_accused, v_top_count
  FROM final_votes
  WHERE room_id = p_room_id AND is_tie_breaker = p_is_tie_breaker
  GROUP BY suspect_player_id
  ORDER BY cnt DESC, suspect_player_id
  LIMIT 1;

  IF v_accused IS NULL THEN
    IF v_room.status = 'tie_breaker' AND v_room.tie_breaker_candidates IS NOT NULL
       AND array_length(v_room.tie_breaker_candidates, 1) > 0 THEN
      v_accused := v_room.tie_breaker_candidates[
        1 + floor(random() * array_length(v_room.tie_breaker_candidates, 1))::int
      ];
    ELSE
      SELECT p.id INTO v_accused FROM players p
      WHERE p.room_id = p_room_id AND p.is_connected = true
        AND EXISTS (
          SELECT 1 FROM suspect_votes sv
          WHERE sv.room_id = p_room_id AND sv.suspect_player_id = p.id
        )
      ORDER BY random() LIMIT 1;

      IF v_accused IS NULL THEN
        SELECT id INTO v_accused FROM players
        WHERE room_id = p_room_id AND is_connected = true
        ORDER BY random() LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF v_accused IS NULL OR v_criminal IS NULL THEN RETURN; END IF;

  SELECT array_agg(suspect_player_id ORDER BY suspect_player_id) INTO v_tied FROM (
    SELECT suspect_player_id, COUNT(*) AS cnt FROM final_votes
    WHERE room_id = p_room_id AND is_tie_breaker = p_is_tie_breaker
    GROUP BY suspect_player_id HAVING COUNT(*) = v_top_count
  ) sub;

  IF v_top_count IS NOT NULL AND array_length(v_tied, 1) > 1 AND NOT p_is_tie_breaker THEN
    UPDATE rooms SET status = 'tie_breaker', tie_breaker_candidates = v_tied,
      phase_ends_at = now() + interval '20 seconds', updated_at = now()
    WHERE id = p_room_id AND status = 'final_vote';
    RETURN;
  END IF;

  IF v_top_count IS NOT NULL AND array_length(v_tied, 1) > 1 THEN
    v_accused := v_tied[1 + floor(random() * array_length(v_tied, 1))::int];
  END IF;

  SELECT source_player_id INTO v_writer FROM evidence WHERE room_id = p_room_id AND is_fake = true LIMIT 1;

  IF v_accused = v_criminal THEN
    v_winner := 'detectives';
  ELSE
    v_winner := 'criminal';
  END IF;

  INSERT INTO game_results (room_id, criminal_player_id, accused_player_id, fake_evidence_writer_id, winning_side)
  VALUES (p_room_id, v_criminal, v_accused, v_writer, v_winner);

  UPDATE rooms SET status = 'results', accused_player_id = v_accused,
    previous_criminal_id = v_criminal, phase_ends_at = NULL, updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_game_results(p_player_id UUID, p_session_token TEXT)
RETURNS JSON AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_result game_results%ROWTYPE;
  v_evidence JSON;
  v_criminal UUID;
  v_criminal_name TEXT;
  v_accused_name TEXT;
  v_fake_writer_name TEXT;
  v_winning_side TEXT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;

  SELECT * INTO v_result FROM game_results
  WHERE room_id = v_player.room_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN RAISE EXCEPTION 'NO_RESULTS'; END IF;

  v_criminal := COALESCE(v_room.criminal_player_id, v_result.criminal_player_id);
  v_result.accused_player_id := COALESCE(v_room.accused_player_id, v_result.accused_player_id);
  v_result.criminal_player_id := v_criminal;

  IF v_result.accused_player_id = v_criminal THEN
    v_winning_side := 'detectives';
  ELSE
    v_winning_side := 'criminal';
  END IF;

  SELECT display_name INTO v_criminal_name FROM players WHERE id = v_criminal;
  SELECT display_name INTO v_accused_name FROM players WHERE id = v_result.accused_player_id;
  SELECT display_name INTO v_fake_writer_name FROM players WHERE id = v_result.fake_evidence_writer_id;

  SELECT json_agg(json_build_object(
    'order', e.evidence_order,
    'text', e.evidence_text,
    'question_text', q.question_text,
    'answer_text', e.answer_text,
    'is_fake', e.is_fake,
    'is_inspected', e.is_inspected,
    'inspection_result', e.inspection_result
  ) ORDER BY e.evidence_order) INTO v_evidence
  FROM evidence e
  LEFT JOIN questions q ON q.id = e.question_id
  WHERE e.room_id = v_player.room_id;

  RETURN json_build_object(
    'criminal_id', v_criminal,
    'criminal_name', v_criminal_name,
    'accused_id', v_result.accused_player_id,
    'accused_name', v_accused_name,
    'fake_writer_id', v_result.fake_evidence_writer_id,
    'fake_writer_name', v_fake_writer_name,
    'winning_side', v_winning_side,
    'evidence', v_evidence
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION play_again(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_prev UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  SELECT criminal_player_id INTO v_prev FROM rooms WHERE id = v_player.room_id;
  IF v_prev IS NULL THEN
    SELECT criminal_player_id INTO v_prev FROM game_results
    WHERE room_id = v_player.room_id ORDER BY created_at DESC LIMIT 1;
  END IF;

  DELETE FROM game_results WHERE room_id = v_player.room_id;
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
    criminal_player_id = NULL,
    previous_criminal_id = COALESCE(v_prev, previous_criminal_id), updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Patch start_game to clear locked criminal from prior rounds
CREATE OR REPLACE FUNCTION start_game(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_count INT;
  v_mc_count INT;
  v_sa_count INT;
  v_mc_ids UUID[];
  v_sa_id UUID;
  v_order INT := 1;
  v_qid UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ROOM_NOT_FOUND'; END IF;
  IF v_room.status != 'lobby' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  SELECT COUNT(*) INTO v_count FROM players
  WHERE room_id = v_player.room_id AND is_connected = true;
  IF v_count < 3 THEN RAISE EXCEPTION 'NOT_ENOUGH_PLAYERS'; END IF;

  SELECT COUNT(*) INTO v_mc_count FROM questions
  WHERE question_type = 'multiple_choice' AND is_active = true;
  SELECT COUNT(*) INTO v_sa_count FROM questions
  WHERE question_type = 'short_answer' AND is_active = true;

  IF v_mc_count < 7 THEN
    RAISE EXCEPTION 'MISSING_QUESTIONS: need at least 7 multiple-choice questions in database';
  END IF;
  IF v_sa_count < 1 THEN
    RAISE EXCEPTION 'MISSING_QUESTIONS: need at least 1 short-answer question in database';
  END IF;

  DELETE FROM player_answers WHERE room_id = v_player.room_id;
  DELETE FROM game_questions WHERE room_id = v_player.room_id;

  WITH by_category AS (
    SELECT DISTINCT ON (category) id
    FROM questions
    WHERE question_type = 'multiple_choice' AND is_active = true AND category IS NOT NULL
    ORDER BY category, random()
  ),
  picked AS (
    SELECT id FROM by_category ORDER BY random()
  ),
  need_more AS (
    SELECT GREATEST(0, 7 - (SELECT COUNT(*) FROM picked)) AS n
  ),
  extras AS (
    SELECT q.id
    FROM questions q, need_more nm
    WHERE q.question_type = 'multiple_choice' AND q.is_active = true
      AND q.id NOT IN (SELECT id FROM picked)
    ORDER BY random()
    LIMIT (SELECT n FROM need_more)
  ),
  combined AS (
    SELECT id FROM picked
    UNION ALL
    SELECT id FROM extras
  )
  SELECT array_agg(id) INTO v_mc_ids FROM (
    SELECT id FROM combined ORDER BY random() LIMIT 7
  ) shuffled;

  SELECT id INTO v_sa_id FROM questions
  WHERE question_type = 'short_answer' AND is_active = true
  ORDER BY random() LIMIT 1;

  FOREACH v_qid IN ARRAY v_mc_ids LOOP
    INSERT INTO game_questions (room_id, question_id, question_order)
    VALUES (v_player.room_id, v_qid, v_order);
    v_order := v_order + 1;
  END LOOP;

  INSERT INTO game_questions (room_id, question_id, question_order)
  VALUES (v_player.room_id, v_sa_id, 8);

  UPDATE rooms SET
    status = 'survey',
    current_question_index = 1,
    current_round = 0,
    criminal_player_id = NULL,
    accused_player_id = NULL,
    updated_at = now()
  WHERE id = v_player.room_id;

  PERFORM advance_survey_question(p_player_id, p_session_token, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Lie detector: use locked criminal for honest/dishonest comparison
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
  v_criminal UUID;
  v_player_name TEXT;
  v_question_text TEXT;
  v_answer_text TEXT;
  v_criminal_answer TEXT;
  v_verdict TEXT;
  v_inspection TEXT;
  v_event INT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_ld'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'lie_detector' THEN RETURN; END IF;

  v_event := v_room.lie_detector_event;
  v_criminal := get_room_criminal(p_room_id);

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
        room_id, event_number, action_type, target_player_id, target_question_id,
        player_name, question_text, answer_text, answer_verdict
      ) VALUES (
        p_room_id, v_event, 'check_answer', v_target_player, v_target_question,
        v_player_name, v_question_text, COALESCE(v_answer_text, 'No answer'), v_verdict
      );
    END IF;
  END IF;

  UPDATE rooms SET phase_ends_at = now() + interval '12 seconds', updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
