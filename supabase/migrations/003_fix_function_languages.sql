-- Run this ONLY if 001_initial_schema.sql failed partway through.
-- Fixes two functions that had LANGUAGE sql but used plpgsql syntax.

CREATE OR REPLACE FUNCTION get_my_role(p_player_id UUID, p_session_token TEXT)
RETURNS TEXT AS $$
DECLARE
  v_role player_role;
BEGIN
  SELECT role INTO v_role FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  RETURN v_role::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION get_answer_count(p_room_id UUID)
RETURNS JSON AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_count INT;
  v_total INT;
BEGIN
  SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
  SELECT COUNT(*) INTO v_count FROM player_answers pa
  JOIN game_questions gq ON gq.question_id = pa.question_id AND gq.room_id = pa.room_id
  WHERE pa.room_id = p_room_id AND gq.question_order = v_room.current_question_index;
  SELECT COUNT(*) INTO v_total FROM players WHERE room_id = p_room_id AND is_connected = true;
  RETURN json_build_object('answered', v_count, 'total', v_total);
END;
$$ LANGUAGE plpgsql STABLE;
