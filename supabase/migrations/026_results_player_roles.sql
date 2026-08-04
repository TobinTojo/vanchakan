-- Expose full player role roster on the game over screen

CREATE OR REPLACE FUNCTION get_game_results(p_player_id UUID, p_session_token TEXT)
RETURNS JSON AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_result game_results%ROWTYPE;
  v_evidence JSON;
  v_roster JSON;
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

  SELECT json_agg(json_build_object(
    'id', p.id,
    'name', p.display_name,
    'role', p.role::text
  ) ORDER BY
    CASE p.role
      WHEN 'criminal' THEN 1
      WHEN 'jester' THEN 2
      ELSE 3
    END,
    p.display_name) INTO v_roster
  FROM players p
  WHERE p.room_id = v_player.room_id
    AND p.is_connected = true
    AND p.role IN ('criminal', 'innocent', 'jester');

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
    'players', COALESCE(v_roster, '[]'::json),
    'evidence', v_evidence
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
