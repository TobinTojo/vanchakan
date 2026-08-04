-- Allow survey to skip to next question when all players have answered

CREATE OR REPLACE FUNCTION advance_survey_question(
  p_player_id UUID,
  p_session_token TEXT,
  p_force BOOLEAN DEFAULT false
)
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

  -- Only wait for timer on automatic expiry ticks, not when everyone has answered
  IF NOT p_force AND v_gq.started_at IS NOT NULL AND v_gq.ends_at > v_now THEN
    RETURN;
  END IF;

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
  END IF;

  UPDATE game_questions SET started_at = v_now, ends_at = v_now + interval '30 seconds'
  WHERE id = v_gq.id;

  UPDATE rooms SET phase_ends_at = v_now + interval '30 seconds', updated_at = now()
  WHERE id = v_player.room_id AND status = 'survey';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_answer(p_player_id UUID, p_session_token TEXT, p_answer_text TEXT)
RETURNS JSON AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_gq game_questions%ROWTYPE;
  v_answered INT;
  v_connected INT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'survey' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  SELECT * INTO v_gq FROM game_questions
  WHERE room_id = v_player.room_id AND question_order = v_room.current_question_index;

  IF v_gq.ends_at < now() THEN RAISE EXCEPTION 'TIME_EXPIRED'; END IF;

  INSERT INTO player_answers (room_id, player_id, question_id, answer_text)
  VALUES (v_player.room_id, p_player_id, v_gq.question_id, trim(p_answer_text))
  ON CONFLICT (room_id, player_id, question_id) DO NOTHING;

  SELECT COUNT(*) INTO v_answered FROM player_answers pa
  JOIN game_questions gq ON gq.question_id = pa.question_id AND gq.room_id = pa.room_id
  WHERE pa.room_id = v_player.room_id AND gq.question_order = v_room.current_question_index;

  SELECT COUNT(*) INTO v_connected FROM players
  WHERE room_id = v_player.room_id AND is_connected = true;

  IF v_answered >= v_connected AND v_connected > 0 THEN
    PERFORM advance_survey_question(p_player_id, p_session_token, true);
  END IF;

  RETURN json_build_object('answered_count', v_answered, 'total', v_connected);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Callable by any client when answer count shows everyone is done
CREATE OR REPLACE FUNCTION try_advance_survey_if_ready(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_answered INT;
  v_connected INT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'survey' THEN RETURN; END IF;

  SELECT COUNT(*) INTO v_answered FROM player_answers pa
  JOIN game_questions gq ON gq.question_id = pa.question_id AND gq.room_id = pa.room_id
  WHERE pa.room_id = v_player.room_id AND gq.question_order = v_room.current_question_index;

  SELECT COUNT(*) INTO v_connected FROM players
  WHERE room_id = v_player.room_id AND is_connected = true;

  IF v_answered >= v_connected AND v_connected > 0 THEN
    PERFORM advance_survey_question(p_player_id, p_session_token, true);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
