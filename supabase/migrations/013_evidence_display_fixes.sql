-- Clearer evidence display, play again for all players, improved format_evidence

CREATE OR REPLACE FUNCTION format_evidence(p_question TEXT, p_answer TEXT, p_type TEXT)
RETURNS TEXT AS $$
DECLARE
  v_question TEXT := trim(p_question);
BEGIN
  -- Strip trailing "You:" from survey prompts for cleaner display
  IF v_question ~* ' You:$' THEN
    v_question := regexp_replace(v_question, ' You:$', '', 'i');
  END IF;

  RETURN v_question || ' → "' || p_answer || '"';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

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
        q.question_text,
        e.is_inspected,
        e.inspection_result,
        e.created_at,
        count_matching_answers(e.room_id, e.question_id, e.answer_text) AS matching_count,
        v_total AS total_players
      FROM evidence e
      LEFT JOIN questions q ON q.id = e.question_id
      WHERE e.room_id = p_room_id
      ORDER BY e.evidence_order
    ) t
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_game_results(p_player_id UUID, p_session_token TEXT)
RETURNS JSON AS $$
DECLARE
  v_player players%ROWTYPE;
  v_result game_results%ROWTYPE;
  v_evidence JSON;
  v_fake_writer_name TEXT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_result FROM game_results WHERE room_id = v_player.room_id ORDER BY created_at DESC LIMIT 1;

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

  SELECT display_name INTO v_fake_writer_name
  FROM players WHERE id = v_result.fake_evidence_writer_id;

  RETURN json_build_object(
    'criminal_id', v_result.criminal_player_id,
    'accused_id', v_result.accused_player_id,
    'fake_writer_id', v_result.fake_evidence_writer_id,
    'fake_writer_name', v_fake_writer_name,
    'winning_side', v_result.winning_side,
    'evidence', v_evidence
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Any connected player can restart to lobby after results
CREATE OR REPLACE FUNCTION play_again(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_prev UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT criminal_player_id INTO v_prev FROM game_results
  WHERE room_id = v_player.room_id ORDER BY created_at DESC LIMIT 1;

  DELETE FROM final_votes WHERE room_id = v_player.room_id;
  DELETE FROM suspect_votes WHERE room_id = v_player.room_id;
  DELETE FROM lie_detector_votes WHERE room_id = v_player.room_id;
  DELETE FROM interrogation_rounds WHERE room_id = v_player.room_id;
  DELETE FROM evidence WHERE room_id = v_player.room_id;
  DELETE FROM player_answers WHERE room_id = v_player.room_id;
  DELETE FROM game_questions WHERE room_id = v_player.room_id;

  UPDATE players SET role = 'unknown', fake_evidence_question_id = NULL WHERE room_id = v_player.room_id;

  UPDATE rooms SET
    status = 'lobby', current_question_index = 0, current_round = 0,
    current_crime_id = NULL, lie_detector_event = 0, phase_ends_at = NULL,
    tie_breaker_candidates = NULL, accused_player_id = NULL,
    previous_criminal_id = COALESCE(v_prev, previous_criminal_id), updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
