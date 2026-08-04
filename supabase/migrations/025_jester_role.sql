-- Jester neutral role: lobby toggle, exclusive win on final accusation

DO $$ BEGIN
  ALTER TYPE player_role ADD VALUE 'jester';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE rooms ADD COLUMN IF NOT EXISTS jester_enabled BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS jester_player_id UUID REFERENCES players(id);

CREATE OR REPLACE FUNCTION set_jester_enabled(
  p_player_id UUID,
  p_session_token TEXT,
  p_enabled BOOLEAN
)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'lobby' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  UPDATE rooms SET jester_enabled = p_enabled, updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION finish_survey(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_criminal_id UUID;
  v_jester_id UUID;
  v_prev UUID;
  v_candidates UUID[];
  v_jester_candidates UUID[];
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_room_id::text || '_finish_survey'));

  SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_room.status != 'survey' THEN RETURN; END IF;

  IF v_room.criminal_player_id IS NOT NULL THEN
    IF v_room.jester_enabled AND v_room.jester_player_id IS NULL THEN
      SELECT array_agg(id) INTO v_jester_candidates FROM players
      WHERE room_id = p_room_id AND is_connected = true AND id != v_room.criminal_player_id;

      IF v_jester_candidates IS NOT NULL AND array_length(v_jester_candidates, 1) > 0 THEN
        v_jester_id := v_jester_candidates[1 + floor(random() * array_length(v_jester_candidates, 1))::int];
        UPDATE players SET role = 'jester' WHERE id = v_jester_id;
        UPDATE rooms SET jester_player_id = v_jester_id WHERE id = p_room_id;
      END IF;
    END IF;

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

  v_jester_id := NULL;
  IF v_room.jester_enabled THEN
    SELECT array_agg(id) INTO v_jester_candidates FROM players
    WHERE room_id = p_room_id AND is_connected = true AND id != v_criminal_id;

    IF v_jester_candidates IS NOT NULL AND array_length(v_jester_candidates, 1) > 0 THEN
      v_jester_id := v_jester_candidates[1 + floor(random() * array_length(v_jester_candidates, 1))::int];
      UPDATE players SET role = 'jester' WHERE id = v_jester_id;
    END IF;
  END IF;

  UPDATE rooms SET
    status = 'role_reveal',
    criminal_player_id = v_criminal_id,
    jester_player_id = v_jester_id,
    phase_ends_at = NULL,
    updated_at = now()
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
  v_jester UUID;
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
  v_jester := v_room.jester_player_id;

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

  IF v_jester IS NOT NULL AND v_accused = v_jester THEN
    v_winner := 'jester';
  ELSIF v_accused = v_criminal THEN
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
  v_jester UUID;
  v_criminal_name TEXT;
  v_accused_name TEXT;
  v_jester_name TEXT;
  v_fake_writer_name TEXT;
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
  v_jester := v_room.jester_player_id;
  v_result.accused_player_id := COALESCE(v_room.accused_player_id, v_result.accused_player_id);
  v_result.criminal_player_id := v_criminal;

  SELECT display_name INTO v_criminal_name FROM players WHERE id = v_criminal;
  SELECT display_name INTO v_accused_name FROM players WHERE id = v_result.accused_player_id;
  SELECT display_name INTO v_jester_name FROM players WHERE id = v_jester;
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
    'jester_id', v_jester,
    'jester_name', v_jester_name,
    'fake_writer_id', v_result.fake_evidence_writer_id,
    'fake_writer_name', v_fake_writer_name,
    'winning_side', v_result.winning_side,
    'evidence', v_evidence
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

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
  IF v_room.jester_enabled AND v_count < 4 THEN
    RAISE EXCEPTION 'JESTER_REQUIRES_FOUR_PLAYERS';
  END IF;

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
    jester_player_id = NULL,
    accused_player_id = NULL,
    updated_at = now()
  WHERE id = v_player.room_id;

  PERFORM advance_survey_question(p_player_id, p_session_token, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
    current_crime_id = NULL, lie_detector_event = 0, lie_detector_step = NULL,
    phase_ends_at = NULL, tie_breaker_candidates = NULL, accused_player_id = NULL,
    criminal_player_id = NULL, jester_player_id = NULL,
    previous_criminal_id = COALESCE(v_prev, previous_criminal_id), updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
