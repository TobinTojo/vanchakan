-- Host-controlled role/crime reveal; fix final vote tie-breaker stalls

CREATE OR REPLACE FUNCTION finish_survey(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_criminal_id UUID;
  v_prev UUID;
  v_candidates UUID[];
BEGIN
  SELECT previous_criminal_id INTO v_prev FROM rooms WHERE id = p_room_id;

  SELECT array_agg(id) INTO v_candidates FROM players
  WHERE room_id = p_room_id AND is_connected = true AND (v_prev IS NULL OR id != v_prev);

  IF v_candidates IS NULL OR array_length(v_candidates, 1) = 0 THEN
    SELECT id INTO v_criminal_id FROM players WHERE room_id = p_room_id AND is_connected = true ORDER BY random() LIMIT 1;
  ELSE
    v_criminal_id := v_candidates[1 + floor(random() * array_length(v_candidates, 1))::int];
  END IF;

  UPDATE players SET role = 'innocent' WHERE room_id = p_room_id;
  UPDATE players SET role = 'criminal' WHERE id = v_criminal_id;

  UPDATE rooms SET
    status = 'role_reveal',
    phase_ends_at = NULL,
    updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION advance_role_reveal_now(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_crime UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status != 'role_reveal' THEN RETURN; END IF;

  SELECT id INTO v_crime FROM crimes WHERE is_active = true ORDER BY random() LIMIT 1;

  UPDATE rooms SET
    status = 'crime_reveal',
    current_crime_id = v_crime,
    phase_ends_at = NULL,
    updated_at = now()
  WHERE id = v_player.room_id AND status = 'role_reveal';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION advance_crime_to_evidence(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  PERFORM generate_evidence_for_room(v_player.room_id);
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

  IF v_accused IS NULL THEN RETURN; END IF;

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

  SELECT id INTO v_criminal FROM players WHERE room_id = p_room_id AND role = 'criminal' LIMIT 1;
  IF v_criminal IS NULL THEN RETURN; END IF;

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

CREATE OR REPLACE FUNCTION submit_final_vote(p_player_id UUID, p_session_token TEXT, p_suspect_id UUID, p_is_tie_breaker BOOLEAN DEFAULT false)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_voted INT;
  v_connected INT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF p_suspect_id = p_player_id THEN RAISE EXCEPTION 'INVALID_VOTE'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
  IF p_is_tie_breaker AND v_room.status != 'tie_breaker' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
  IF NOT p_is_tie_breaker AND v_room.status != 'final_vote' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  IF p_is_tie_breaker AND NOT (p_suspect_id = ANY(v_room.tie_breaker_candidates)) THEN
    RAISE EXCEPTION 'INVALID_VOTE';
  END IF;

  INSERT INTO final_votes (room_id, voter_player_id, suspect_player_id, is_tie_breaker)
  VALUES (v_player.room_id, p_player_id, p_suspect_id, p_is_tie_breaker)
  ON CONFLICT DO NOTHING;

  SELECT COUNT(DISTINCT voter_player_id) INTO v_voted FROM final_votes
  WHERE room_id = v_player.room_id AND is_tie_breaker = p_is_tie_breaker;
  SELECT COUNT(*) INTO v_connected FROM players WHERE room_id = v_player.room_id AND is_connected = true;

  IF v_voted >= v_connected THEN
    PERFORM resolve_final_vote(v_player.room_id, p_is_tie_breaker);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
