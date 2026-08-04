-- Fix start_game failures (400 errors from leftover data, missing questions, etc.)

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

  -- Clear leftover data from a previously failed start
  DELETE FROM player_answers WHERE room_id = v_player.room_id;
  DELETE FROM game_questions WHERE room_id = v_player.room_id;

  SELECT array_agg(id) INTO v_mc_ids
  FROM (
    SELECT id FROM questions
    WHERE question_type = 'multiple_choice' AND is_active = true
    ORDER BY random() LIMIT 7
  ) sub;

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
    updated_at = now()
  WHERE id = v_player.room_id;

  PERFORM advance_survey_question(p_player_id, p_session_token, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
