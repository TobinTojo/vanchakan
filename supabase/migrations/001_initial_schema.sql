-- Vanchakan Database Schema
-- Run this migration in Supabase SQL Editor or via supabase db push

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums
CREATE TYPE room_status AS ENUM (
  'lobby', 'survey', 'role_reveal', 'fake_evidence', 'crime_reveal',
  'evidence', 'interrogation', 'lie_detector', 'suspect_vote',
  'final_vote', 'tie_breaker', 'results', 'finished'
);

CREATE TYPE question_type AS ENUM ('multiple_choice', 'short_answer');
CREATE TYPE player_role AS ENUM ('innocent', 'criminal', 'unknown');
CREATE TYPE lie_detector_action AS ENUM ('inspect_evidence', 'check_answer');

-- Questions table (seed data)
CREATE TABLE questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_text TEXT NOT NULL,
  question_type question_type NOT NULL,
  options JSONB,
  category TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Crimes table (seed data)
CREATE TABLE crimes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  crime_text TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Rooms table
CREATE TABLE rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_code TEXT UNIQUE NOT NULL,
  host_player_id UUID,
  status room_status DEFAULT 'lobby',
  current_question_index INT DEFAULT 0,
  current_round INT DEFAULT 0,
  current_crime_id UUID REFERENCES crimes(id),
  lie_detector_event INT DEFAULT 0,
  phase_ends_at TIMESTAMPTZ,
  tie_breaker_candidates UUID[],
  accused_player_id UUID,
  previous_criminal_id UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Players table
CREATE TABLE players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  session_token TEXT NOT NULL,
  is_host BOOLEAN DEFAULT false,
  is_connected BOOLEAN DEFAULT true,
  role player_role DEFAULT 'unknown',
  previous_role player_role,
  fake_evidence_question_id UUID REFERENCES questions(id),
  joined_at TIMESTAMPTZ DEFAULT now(),
  last_seen_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, display_name)
);

ALTER TABLE rooms ADD CONSTRAINT fk_host_player
  FOREIGN KEY (host_player_id) REFERENCES players(id) ON DELETE SET NULL;

-- Game questions (selected for this game)
CREATE TABLE game_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES questions(id),
  question_order INT NOT NULL,
  started_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  UNIQUE(room_id, question_order)
);

-- Player answers
CREATE TABLE player_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES questions(id),
  answer_text TEXT NOT NULL,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, player_id, question_id)
);

-- Evidence
CREATE TABLE evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  evidence_order INT NOT NULL,
  question_id UUID REFERENCES questions(id),
  evidence_text TEXT NOT NULL,
  source_player_id UUID REFERENCES players(id),
  is_fake BOOLEAN DEFAULT false,
  is_inspected BOOLEAN DEFAULT false,
  inspection_result TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, evidence_order)
);

-- Interrogation rounds
CREATE TABLE interrogation_rounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  round_number INT NOT NULL,
  evidence_id UUID NOT NULL REFERENCES evidence(id),
  suspect_player_id UUID NOT NULL REFERENCES players(id),
  suspect_response TEXT,
  started_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  UNIQUE(room_id, round_number)
);

-- Lie detector votes
CREATE TABLE lie_detector_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  event_number INT NOT NULL,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  action_type lie_detector_action NOT NULL,
  target_evidence_id UUID REFERENCES evidence(id),
  target_player_id UUID REFERENCES players(id),
  target_question_id UUID REFERENCES questions(id),
  submitted_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, event_number, player_id)
);

-- Suspect votes (top 2)
CREATE TABLE suspect_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  voter_player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  suspect_player_id UUID NOT NULL REFERENCES players(id),
  vote_rank INT NOT NULL CHECK (vote_rank IN (1, 2)),
  submitted_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, voter_player_id, vote_rank)
);

-- Final votes
CREATE TABLE final_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  voter_player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  suspect_player_id UUID NOT NULL REFERENCES players(id),
  is_tie_breaker BOOLEAN DEFAULT false,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, voter_player_id, is_tie_breaker)
);

-- Game results
CREATE TABLE game_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  criminal_player_id UUID REFERENCES players(id),
  accused_player_id UUID REFERENCES players(id),
  fake_evidence_writer_id UUID REFERENCES players(id),
  winning_side TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_players_room ON players(room_id);
CREATE INDEX idx_players_session ON players(session_token);
CREATE INDEX idx_rooms_code ON rooms(room_code);
CREATE INDEX idx_player_answers_room ON player_answers(room_id);
CREATE INDEX idx_evidence_room ON evidence(room_id);
CREATE INDEX idx_game_questions_room ON game_questions(room_id);

-- Public view for evidence (hides is_fake and source_player_id)
CREATE VIEW public_evidence AS
SELECT
  id, room_id, evidence_order, evidence_text,
  is_inspected, inspection_result, created_at
FROM evidence;

-- Public view for players (hides role)
CREATE VIEW public_players AS
SELECT
  id, room_id, display_name, is_host, is_connected,
  joined_at, last_seen_at
FROM players;

-- Helper: validate session
CREATE OR REPLACE FUNCTION validate_player(p_player_id UUID, p_session_token TEXT)
RETURNS players AS $$
  SELECT * FROM players
  WHERE id = p_player_id AND session_token = p_session_token
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper: get connected player count
CREATE OR REPLACE FUNCTION connected_player_count(p_room_id UUID)
RETURNS INT AS $$
  SELECT COUNT(*)::INT FROM players
  WHERE room_id = p_room_id AND is_connected = true;
$$ LANGUAGE sql STABLE;

-- Helper: generate room code
CREATE OR REPLACE FUNCTION generate_room_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Create room
CREATE OR REPLACE FUNCTION create_room(p_display_name TEXT, p_session_token TEXT)
RETURNS JSON AS $$
DECLARE
  v_room_id UUID;
  v_player_id UUID;
  v_code TEXT;
  v_attempts INT := 0;
BEGIN
  LOOP
    v_code := generate_room_code();
    BEGIN
      INSERT INTO rooms (room_code) VALUES (v_code) RETURNING id INTO v_room_id;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_attempts := v_attempts + 1;
      IF v_attempts > 10 THEN RAISE EXCEPTION 'Could not generate unique room code'; END IF;
    END;
  END LOOP;

  INSERT INTO players (room_id, display_name, session_token, is_host, is_connected)
  VALUES (v_room_id, p_display_name, p_session_token, true, true)
  RETURNING id INTO v_player_id;

  UPDATE rooms SET host_player_id = v_player_id WHERE id = v_room_id;

  RETURN json_build_object(
    'room_id', v_room_id,
    'player_id', v_player_id,
    'room_code', v_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Join room
CREATE OR REPLACE FUNCTION join_room(p_room_code TEXT, p_display_name TEXT, p_session_token TEXT)
RETURNS JSON AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_player_id UUID;
  v_count INT;
BEGIN
  SELECT * INTO v_room FROM rooms WHERE room_code = upper(trim(p_room_code));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ROOM_NOT_FOUND';
  END IF;

  IF v_room.status != 'lobby' THEN
    RAISE EXCEPTION 'GAME_ALREADY_STARTED';
  END IF;

  SELECT COUNT(*) INTO v_count FROM players WHERE room_id = v_room.id;
  IF v_count >= 8 THEN
    RAISE EXCEPTION 'ROOM_FULL';
  END IF;

  IF EXISTS (SELECT 1 FROM players WHERE room_id = v_room.id AND lower(display_name) = lower(trim(p_display_name))) THEN
    RAISE EXCEPTION 'DUPLICATE_NAME';
  END IF;

  INSERT INTO players (room_id, display_name, session_token, is_host, is_connected)
  VALUES (v_room.id, trim(p_display_name), p_session_token, false, true)
  RETURNING id INTO v_player_id;

  RETURN json_build_object(
    'room_id', v_room.id,
    'player_id', v_player_id,
    'room_code', v_room.room_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reconnect player
CREATE OR REPLACE FUNCTION reconnect_player(p_player_id UUID, p_session_token TEXT)
RETURNS JSON AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_next_host UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  UPDATE players SET is_connected = true, last_seen_at = now()
  WHERE id = p_player_id;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;

  IF NOT EXISTS (
    SELECT 1 FROM players WHERE room_id = v_player.room_id AND is_host = true AND is_connected = true
  ) THEN
    SELECT id INTO v_next_host FROM players
    WHERE room_id = v_player.room_id AND is_connected = true
    ORDER BY joined_at LIMIT 1;

    IF v_next_host IS NOT NULL THEN
      UPDATE players SET is_host = false WHERE room_id = v_player.room_id;
      UPDATE players SET is_host = true WHERE id = v_next_host;
      UPDATE rooms SET host_player_id = v_next_host WHERE id = v_player.room_id;
    END IF;
  END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;

  RETURN json_build_object(
    'room_id', v_player.room_id,
    'player_id', p_player_id,
    'room_code', v_room.room_code,
    'status', v_room.status
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Leave room
CREATE OR REPLACE FUNCTION leave_room(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_next_host UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  UPDATE players SET is_connected = false, last_seen_at = now()
  WHERE id = p_player_id;

  IF v_player.is_host THEN
    SELECT id INTO v_next_host FROM players
    WHERE room_id = v_player.room_id AND id != p_player_id AND is_connected = true
    ORDER BY joined_at LIMIT 1;

    IF v_next_host IS NOT NULL THEN
      UPDATE players SET is_host = false WHERE room_id = v_player.room_id;
      UPDATE players SET is_host = true WHERE id = v_next_host;
      UPDATE rooms SET host_player_id = v_next_host WHERE id = v_player.room_id;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Heartbeat
CREATE OR REPLACE FUNCTION player_heartbeat(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM validate_player(p_player_id, p_session_token)) THEN
    RAISE EXCEPTION 'INVALID_SESSION';
  END IF;
  UPDATE players SET last_seen_at = now(), is_connected = true WHERE id = p_player_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Start game (host only)
CREATE OR REPLACE FUNCTION start_game(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_count INT;
  v_mc_ids UUID[];
  v_sa_id UUID;
  v_order INT := 1;
  v_qid UUID;
  v_now TIMESTAMPTZ := now();
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND OR NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'lobby' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  SELECT COUNT(*) INTO v_count FROM players WHERE room_id = v_player.room_id AND is_connected = true;
  IF v_count < 3 THEN RAISE EXCEPTION 'NOT_ENOUGH_PLAYERS'; END IF;

  SELECT array_agg(id ORDER BY random()) INTO v_mc_ids
  FROM (SELECT id FROM questions WHERE question_type = 'multiple_choice' AND is_active = true ORDER BY random() LIMIT 7) sub;

  SELECT id INTO v_sa_id FROM questions
  WHERE question_type = 'short_answer' AND is_active = true
  ORDER BY random() LIMIT 1;

  FOREACH v_qid IN ARRAY v_mc_ids LOOP
    INSERT INTO game_questions (room_id, question_id, question_order) VALUES (v_player.room_id, v_qid, v_order);
    v_order := v_order + 1;
  END LOOP;

  INSERT INTO game_questions (room_id, question_id, question_order) VALUES (v_player.room_id, v_sa_id, 8);

  UPDATE rooms SET
    status = 'survey',
    current_question_index = 1,
    updated_at = now()
  WHERE id = v_player.room_id;

  PERFORM advance_survey_question(p_player_id, p_session_token);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Advance survey question
CREATE OR REPLACE FUNCTION advance_survey_question(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_gq game_questions%ROWTYPE;
  v_now TIMESTAMPTZ := now();
  v_connected INT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.status != 'survey' THEN RETURN; END IF;

  SELECT * INTO v_gq FROM game_questions
  WHERE room_id = v_player.room_id AND question_order = v_room.current_question_index;

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
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_room.current_question_index >= 8 THEN
    PERFORM finish_survey(v_player.room_id);
    RETURN;
  END IF;

  IF v_gq.started_at IS NOT NULL THEN
    UPDATE rooms SET current_question_index = current_question_index + 1, updated_at = now()
    WHERE id = v_player.room_id;
    SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
    SELECT * INTO v_gq FROM game_questions
    WHERE room_id = v_player.room_id AND question_order = v_room.current_question_index;
  END IF;

  UPDATE game_questions SET started_at = v_now, ends_at = v_now + interval '30 seconds'
  WHERE id = v_gq.id;

  UPDATE rooms SET phase_ends_at = v_now + interval '30 seconds', updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Submit answer
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

  IF v_answered >= v_connected THEN
    PERFORM advance_survey_question(p_player_id, p_session_token);
  END IF;

  RETURN json_build_object('answered_count', v_answered, 'total', v_connected);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Finish survey and assign criminal
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
    phase_ends_at = now() + interval '8 seconds',
    updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get my role (private)
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

-- Advance from role reveal
CREATE OR REPLACE FUNCTION advance_from_role_reveal(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_room rooms%ROWTYPE;
  v_writer UUID; v_fake_q UUID; v_crime UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND OR NOT v_player.is_host THEN RETURN; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'role_reveal' OR v_room.phase_ends_at > now() THEN RETURN; END IF;

  SELECT id INTO v_crime FROM crimes WHERE is_active = true ORDER BY random() LIMIT 1;
  UPDATE rooms SET status = 'crime_reveal', current_crime_id = v_crime,
    phase_ends_at = now() + interval '6 seconds', updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Advance from crime reveal to fake evidence
CREATE OR REPLACE FUNCTION advance_from_crime_reveal(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_writer UUID;
  v_fake_q UUID;
  v_criminal UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND OR NOT v_player.is_host THEN RETURN; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'crime_reveal' OR v_room.phase_ends_at > now() THEN RETURN; END IF;

  SELECT id INTO v_criminal FROM players WHERE room_id = v_player.room_id AND role = 'criminal';

  SELECT id INTO v_writer FROM players
  WHERE room_id = v_player.room_id AND role = 'innocent' AND is_connected = true
  ORDER BY random() LIMIT 1;

  SELECT gq.question_id INTO v_fake_q FROM game_questions gq
  WHERE gq.room_id = v_player.room_id
  ORDER BY random() LIMIT 1;

  UPDATE players SET fake_evidence_question_id = v_fake_q WHERE id = v_writer;

  UPDATE rooms SET status = 'fake_evidence', phase_ends_at = now() + interval '30 seconds', updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get fake evidence task (private)
CREATE OR REPLACE FUNCTION get_fake_evidence_task(p_player_id UUID, p_session_token TEXT)
RETURNS JSON AS $$
DECLARE v_player players%ROWTYPE; v_q questions%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF v_player.fake_evidence_question_id IS NULL THEN RETURN NULL; END IF;
  SELECT * INTO v_q FROM questions WHERE id = v_player.fake_evidence_question_id;
  RETURN json_build_object('question_id', v_q.id, 'question_text', v_q.question_text, 'question_type', v_q.question_type, 'options', v_q.options);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Submit fake evidence
CREATE OR REPLACE FUNCTION submit_fake_evidence(p_player_id UUID, p_session_token TEXT, p_answer_text TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF v_player.fake_evidence_question_id IS NULL THEN RAISE EXCEPTION 'NOT_FAKE_WRITER'; END IF;

  INSERT INTO player_answers (room_id, player_id, question_id, answer_text)
  VALUES (v_player.room_id, p_player_id, v_player.fake_evidence_question_id, trim(p_answer_text))
  ON CONFLICT (room_id, player_id, question_id) DO UPDATE SET answer_text = trim(p_answer_text);

  PERFORM try_generate_evidence(v_player.room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Try generate evidence
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
BEGIN
  SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
  IF v_room.status != 'fake_evidence' THEN RETURN; END IF;

  SELECT id INTO v_criminal FROM players WHERE room_id = p_room_id AND role = 'criminal';
  SELECT id, fake_evidence_question_id INTO v_writer, v_fake_q FROM players
  WHERE room_id = p_room_id AND fake_evidence_question_id IS NOT NULL LIMIT 1;

  IF v_room.phase_ends_at > now() THEN
    IF NOT EXISTS (SELECT 1 FROM player_answers WHERE room_id = p_room_id AND player_id = v_writer AND question_id = v_fake_q) THEN
      RETURN;
    END IF;
  END IF;

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

  SELECT pa.answer_text INTO v_fake_text FROM player_answers pa
  WHERE pa.room_id = p_room_id AND pa.player_id = v_writer AND pa.question_id = v_fake_q;

  IF v_fake_text IS NULL THEN
    SELECT pa.answer_text INTO v_fake_text FROM player_answers pa
    JOIN players p ON p.id = pa.player_id
    WHERE pa.room_id = p_room_id AND p.role = 'innocent' AND pa.question_id = v_fake_q
    ORDER BY random() LIMIT 1;
    IF v_fake_text IS NULL THEN v_fake_text := 'Unknown'; END IF;
  END IF;

  SELECT question_text INTO v_evidence_text FROM questions WHERE id = v_fake_q;
  v_evidence_text := format_evidence(v_evidence_text, v_fake_text, (SELECT question_type::text FROM questions WHERE id = v_fake_q));

  INSERT INTO evidence (room_id, evidence_order, question_id, evidence_text, source_player_id, is_fake)
  VALUES (p_room_id, v_order, v_fake_q, v_evidence_text, v_writer, true);

  UPDATE evidence SET evidence_order = sub.new_order
  FROM (
    SELECT id, row_number() OVER (ORDER BY random()) as new_order
    FROM evidence WHERE room_id = p_room_id
  ) sub WHERE evidence.id = sub.id;

  UPDATE rooms SET status = 'evidence', phase_ends_at = now() + interval '15 seconds', updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Format evidence text
CREATE OR REPLACE FUNCTION format_evidence(p_question TEXT, p_answer TEXT, p_type TEXT)
RETURNS TEXT AS $$
BEGIN
  IF p_type = 'short_answer' THEN
    RETURN 'The criminal ' || lower(substring(p_question from 1 for 1)) || substring(p_question from 2) || ' Answer: "' || p_answer || '".';
  ELSE
    RETURN 'The criminal admits: when asked "' || p_question || '" they answered "' || p_answer || '".';
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Advance from evidence board to interrogation
CREATE OR REPLACE FUNCTION start_interrogation(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_suspects UUID[];
  v_evidence_ids UUID[];
  v_i INT;
  v_round INT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND OR NOT v_player.is_host THEN RETURN; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'evidence' THEN RETURN; END IF;

  SELECT array_agg(id ORDER BY joined_at) INTO v_suspects FROM players WHERE room_id = v_player.room_id AND is_connected = true;
  SELECT array_agg(id ORDER BY evidence_order) INTO v_evidence_ids FROM evidence WHERE room_id = v_player.room_id;

  DELETE FROM interrogation_rounds WHERE room_id = v_player.room_id;

  FOR v_i IN 1..6 LOOP
    INSERT INTO interrogation_rounds (room_id, round_number, evidence_id, suspect_player_id, started_at, ends_at)
    VALUES (
      v_player.room_id, v_i,
      v_evidence_ids[1 + ((v_i - 1) % array_length(v_evidence_ids, 1))],
      v_suspects[1 + ((v_i - 1) % array_length(v_suspects, 1))],
      NULL, NULL
    );
  END LOOP;

  UPDATE rooms SET status = 'interrogation', current_round = 1, updated_at = now()
  WHERE id = v_player.room_id;

  PERFORM start_interrogation_round(p_player_id, p_session_token);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Start interrogation round
CREATE OR REPLACE FUNCTION start_interrogation_round(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_room rooms%ROWTYPE; v_now TIMESTAMPTZ := now();
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'interrogation' THEN RETURN; END IF;

  UPDATE interrogation_rounds SET started_at = v_now, ends_at = v_now + interval '60 seconds', completed_at = NULL
  WHERE room_id = v_player.room_id AND round_number = v_room.current_round;

  UPDATE rooms SET phase_ends_at = v_now + interval '60 seconds', updated_at = now()
  WHERE id = v_player.room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Submit interrogation response
CREATE OR REPLACE FUNCTION submit_interrogation_response(p_player_id UUID, p_session_token TEXT, p_response TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_room rooms%ROWTYPE; v_round interrogation_rounds%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;

  SELECT * INTO v_round FROM interrogation_rounds
  WHERE room_id = v_player.room_id AND round_number = v_room.current_round;

  IF v_round.suspect_player_id != p_player_id THEN RAISE EXCEPTION 'NOT_SUSPECT'; END IF;

  UPDATE interrogation_rounds SET suspect_response = trim(p_response)
  WHERE id = v_round.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Next interrogation round (host)
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

  UPDATE rooms SET current_round = current_round + 1, updated_at = now() WHERE id = v_player.room_id;
  PERFORM start_interrogation_round(p_player_id, p_session_token);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Lie detector vote
CREATE OR REPLACE FUNCTION submit_lie_detector_vote(
  p_player_id UUID, p_session_token TEXT, p_action lie_detector_action,
  p_target_evidence_id UUID DEFAULT NULL, p_target_player_id UUID DEFAULT NULL, p_target_question_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_room rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'lie_detector' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  INSERT INTO lie_detector_votes (room_id, event_number, player_id, action_type, target_evidence_id, target_player_id, target_question_id)
  VALUES (v_player.room_id, v_room.lie_detector_event, p_player_id, p_action, p_target_evidence_id, p_target_player_id, p_target_question_id)
  ON CONFLICT (room_id, event_number, player_id) DO UPDATE SET
    action_type = p_action, target_evidence_id = p_target_evidence_id,
    target_player_id = p_target_player_id, target_question_id = p_target_question_id;

  PERFORM try_resolve_lie_detector(v_player.room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resolve lie detector
CREATE OR REPLACE FUNCTION try_resolve_lie_detector(p_room_id UUID)
RETURNS VOID AS $$
DECLARE
  v_room rooms%ROWTYPE;
  v_voted INT; v_connected INT;
  v_action lie_detector_action;
  v_host UUID;
BEGIN
  SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
  SELECT COUNT(*) INTO v_voted FROM lie_detector_votes WHERE room_id = p_room_id AND event_number = v_room.lie_detector_event;
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
    WHERE id = p_room_id;
  ELSE
    UPDATE rooms SET status = 'interrogation', current_round = current_round + 1,
      phase_ends_at = now() + interval '60 seconds', updated_at = now()
    WHERE id = p_room_id;
    PERFORM start_interrogation_round(v_host, (SELECT session_token FROM players WHERE id = v_host));
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get lie detector answer reveal
CREATE OR REPLACE FUNCTION get_lie_detector_answer(p_room_id UUID, p_event_number INT)
RETURNS JSON AS $$
DECLARE v_rec RECORD;
BEGIN
  SELECT ld.target_player_id, ld.target_question_id, p.display_name, q.question_text, pa.answer_text
  INTO v_rec
  FROM lie_detector_votes ld
  JOIN players p ON p.id = ld.target_player_id
  JOIN questions q ON q.id = ld.target_question_id
  LEFT JOIN player_answers pa ON pa.player_id = ld.target_player_id AND pa.question_id = ld.target_question_id AND pa.room_id = p_room_id
  WHERE ld.room_id = p_room_id AND ld.event_number = p_event_number AND ld.action_type = 'check_answer'
  GROUP BY ld.target_player_id, ld.target_question_id, p.display_name, q.question_text, pa.answer_text
  ORDER BY COUNT(*) DESC LIMIT 1;

  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN json_build_object('player_name', v_rec.display_name, 'question', v_rec.question_text, 'answer', COALESCE(v_rec.answer_text, 'No answer'));
END;
$$ LANGUAGE plpgsql STABLE;

-- Suspect votes
CREATE OR REPLACE FUNCTION submit_suspect_votes(p_player_id UUID, p_session_token TEXT, p_suspect1 UUID, p_suspect2 UUID)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_room rooms%ROWTYPE; v_voted INT; v_connected INT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF p_suspect1 = p_player_id OR p_suspect2 = p_player_id OR p_suspect1 = p_suspect2 THEN RAISE EXCEPTION 'INVALID_VOTE'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'suspect_vote' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  INSERT INTO suspect_votes (room_id, voter_player_id, suspect_player_id, vote_rank)
  VALUES (v_player.room_id, p_player_id, p_suspect1, 1), (v_player.room_id, p_player_id, p_suspect2, 2)
  ON CONFLICT DO NOTHING;

  SELECT COUNT(DISTINCT voter_player_id) INTO v_voted FROM suspect_votes WHERE room_id = v_player.room_id;
  SELECT COUNT(*) INTO v_connected FROM players WHERE room_id = v_player.room_id AND is_connected = true;

  IF v_voted >= v_connected OR v_room.phase_ends_at <= now() THEN
    PERFORM resolve_suspect_vote(v_player.room_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resolve suspect vote
CREATE OR REPLACE FUNCTION resolve_suspect_vote(p_room_id UUID)
RETURNS VOID AS $$
DECLARE v_finalists UUID[];
BEGIN
  SELECT array_agg(p.id) INTO v_finalists FROM players p
  WHERE p.room_id = p_room_id AND p.is_connected = true
  AND EXISTS (SELECT 1 FROM suspect_votes sv WHERE sv.room_id = p_room_id AND sv.suspect_player_id = p.id);

  IF v_finalists IS NULL OR array_length(v_finalists, 1) <= 1 THEN
    SELECT array_agg(id) INTO v_finalists FROM players WHERE room_id = p_room_id AND is_connected = true;
  END IF;

  UPDATE rooms SET status = 'final_vote', phase_ends_at = now() + interval '30 seconds', updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Final vote
CREATE OR REPLACE FUNCTION submit_final_vote(p_player_id UUID, p_session_token TEXT, p_suspect_id UUID, p_is_tie_breaker BOOLEAN DEFAULT false)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_room rooms%ROWTYPE; v_voted INT; v_connected INT;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF p_suspect_id = p_player_id THEN RAISE EXCEPTION 'INVALID_VOTE'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status NOT IN ('final_vote', 'tie_breaker') THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  INSERT INTO final_votes (room_id, voter_player_id, suspect_player_id, is_tie_breaker)
  VALUES (v_player.room_id, p_player_id, p_suspect_id, p_is_tie_breaker)
  ON CONFLICT DO NOTHING;

  SELECT COUNT(DISTINCT voter_player_id) INTO v_voted FROM final_votes
  WHERE room_id = v_player.room_id AND is_tie_breaker = p_is_tie_breaker;
  SELECT COUNT(*) INTO v_connected FROM players WHERE room_id = v_player.room_id AND is_connected = true;

  IF v_voted >= v_connected OR v_room.phase_ends_at <= now() THEN
    PERFORM resolve_final_vote(v_player.room_id, p_is_tie_breaker);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resolve final vote
CREATE OR REPLACE FUNCTION resolve_final_vote(p_room_id UUID, p_is_tie_breaker BOOLEAN DEFAULT false)
RETURNS VOID AS $$
DECLARE
  v_accused UUID;
  v_top_count INT;
  v_tied UUID[];
  v_criminal UUID;
  v_writer UUID;
  v_winner TEXT;
BEGIN
  SELECT suspect_player_id, COUNT(*) as cnt INTO v_accused, v_top_count
  FROM final_votes WHERE room_id = p_room_id AND is_tie_breaker = p_is_tie_breaker
  GROUP BY suspect_player_id ORDER BY cnt DESC LIMIT 1;

  SELECT array_agg(suspect_player_id) INTO v_tied FROM (
    SELECT suspect_player_id, COUNT(*) as cnt FROM final_votes
    WHERE room_id = p_room_id AND is_tie_breaker = p_is_tie_breaker
    GROUP BY suspect_player_id HAVING COUNT(*) = v_top_count
  ) sub;

  IF array_length(v_tied, 1) > 1 AND NOT p_is_tie_breaker THEN
    UPDATE rooms SET status = 'tie_breaker', tie_breaker_candidates = v_tied,
      phase_ends_at = now() + interval '20 seconds', updated_at = now()
    WHERE id = p_room_id;
    RETURN;
  END IF;

  IF array_length(v_tied, 1) > 1 THEN
    v_accused := v_tied[1 + floor(random() * array_length(v_tied, 1))::int];
  END IF;

  SELECT id INTO v_criminal FROM players WHERE room_id = p_room_id AND role = 'criminal';
  SELECT source_player_id INTO v_writer FROM evidence WHERE room_id = p_room_id AND is_fake = true LIMIT 1;

  IF v_accused = v_criminal THEN v_winner := 'detectives'; ELSE v_winner := 'criminal'; END IF;

  INSERT INTO game_results (room_id, criminal_player_id, accused_player_id, fake_evidence_writer_id, winning_side)
  VALUES (p_room_id, v_criminal, v_accused, v_writer, v_winner);

  UPDATE rooms SET status = 'results', accused_player_id = v_accused,
    previous_criminal_id = v_criminal, phase_ends_at = NULL, updated_at = now()
  WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get full results (after game end)
CREATE OR REPLACE FUNCTION get_game_results(p_player_id UUID, p_session_token TEXT)
RETURNS JSON AS $$
DECLARE
  v_player players%ROWTYPE;
  v_result game_results%ROWTYPE;
  v_evidence JSON;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_result FROM game_results WHERE room_id = v_player.room_id ORDER BY created_at DESC LIMIT 1;

  SELECT json_agg(json_build_object(
    'order', evidence_order, 'text', evidence_text, 'is_fake', is_fake,
    'is_inspected', is_inspected, 'inspection_result', inspection_result
  ) ORDER BY evidence_order) INTO v_evidence
  FROM evidence WHERE room_id = v_player.room_id;

  RETURN json_build_object(
    'criminal_id', v_result.criminal_player_id,
    'accused_id', v_result.accused_player_id,
    'fake_writer_id', v_result.fake_evidence_writer_id,
    'winning_side', v_result.winning_side,
    'evidence', v_evidence
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Play again
CREATE OR REPLACE FUNCTION play_again(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_prev UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND OR NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

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

-- Return to lobby after results (same as play again but from results screen)
CREATE OR REPLACE FUNCTION return_to_lobby(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
BEGIN PERFORM play_again(p_player_id, p_session_token); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Auto tick (called by clients periodically)
CREATE OR REPLACE FUNCTION game_tick(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE v_player players%ROWTYPE; v_room rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RETURN; END IF;
  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF v_room.phase_ends_at IS NULL OR v_room.phase_ends_at > now() THEN RETURN; END IF;

  CASE v_room.status
    WHEN 'survey' THEN PERFORM advance_survey_question(p_player_id, p_session_token);
    WHEN 'role_reveal' THEN PERFORM advance_from_role_reveal(p_player_id, p_session_token);
    WHEN 'crime_reveal' THEN PERFORM advance_from_crime_reveal(p_player_id, p_session_token);
    WHEN 'fake_evidence' THEN PERFORM try_generate_evidence(v_player.room_id);
    WHEN 'evidence' THEN NULL;
    WHEN 'lie_detector' THEN PERFORM try_resolve_lie_detector(v_player.room_id);
    WHEN 'suspect_vote' THEN PERFORM resolve_suspect_vote(v_player.room_id);
    WHEN 'final_vote', 'tie_breaker' THEN PERFORM resolve_final_vote(v_player.room_id, v_room.status = 'tie_breaker');
    ELSE NULL;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Answer count for current question
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

-- Suspect vote results
CREATE OR REPLACE FUNCTION get_suspect_vote_results(p_room_id UUID)
RETURNS JSON AS $$
  SELECT COALESCE(json_agg(json_build_object(
    'player_id', p.id, 'name', p.display_name,
    'votes', COALESCE(v.cnt, 0),
    'eliminated', COALESCE(v.cnt, 0) = 0
  ) ORDER BY COALESCE(v.cnt, 0) DESC), '[]'::json)
  FROM players p
  LEFT JOIN (
    SELECT suspect_player_id, COUNT(*) as cnt FROM suspect_votes
    WHERE room_id = p_room_id GROUP BY suspect_player_id
  ) v ON v.suspect_player_id = p.id
  WHERE p.room_id = p_room_id AND p.is_connected = true;
$$ LANGUAGE sql STABLE;

-- RLS Policies
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE interrogation_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE lie_detector_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE suspect_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE final_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE crimes ENABLE ROW LEVEL SECURITY;

-- Public read for questions and crimes
CREATE POLICY "questions_read" ON questions FOR SELECT USING (is_active = true);
CREATE POLICY "crimes_read" ON crimes FOR SELECT USING (is_active = true);

-- Rooms: anyone can read (needed for realtime)
CREATE POLICY "rooms_read" ON rooms FOR SELECT USING (true);

-- Players: read public fields only via view, but allow select for realtime (role hidden client-side via view)
CREATE POLICY "players_read" ON players FOR SELECT USING (true);

-- Game data read policies
CREATE POLICY "gq_read" ON game_questions FOR SELECT USING (true);
CREATE POLICY "pa_read" ON player_answers FOR SELECT USING (true);
CREATE POLICY "evidence_read" ON evidence FOR SELECT USING (true);
CREATE POLICY "ir_read" ON interrogation_rounds FOR SELECT USING (true);
CREATE POLICY "ldv_read" ON lie_detector_votes FOR SELECT USING (true);
CREATE POLICY "sv_read" ON suspect_votes FOR SELECT USING (true);
CREATE POLICY "fv_read" ON final_votes FOR SELECT USING (true);
CREATE POLICY "gr_read" ON game_results FOR SELECT USING (true);

-- No direct inserts/updates from client - all via RPC
CREATE POLICY "no_direct_insert_rooms" ON rooms FOR INSERT WITH CHECK (false);
CREATE POLICY "no_direct_update_rooms" ON rooms FOR UPDATE USING (false);
CREATE POLICY "no_direct_insert_players" ON players FOR INSERT WITH CHECK (false);
CREATE POLICY "no_direct_update_players" ON players FOR UPDATE USING (false);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE players;
ALTER PUBLICATION supabase_realtime ADD TABLE game_questions;
ALTER PUBLICATION supabase_realtime ADD TABLE player_answers;
ALTER PUBLICATION supabase_realtime ADD TABLE evidence;
ALTER PUBLICATION supabase_realtime ADD TABLE interrogation_rounds;
ALTER PUBLICATION supabase_realtime ADD TABLE lie_detector_votes;
ALTER PUBLICATION supabase_realtime ADD TABLE suspect_votes;
ALTER PUBLICATION supabase_realtime ADD TABLE final_votes;
ALTER PUBLICATION supabase_realtime ADD TABLE game_results;
