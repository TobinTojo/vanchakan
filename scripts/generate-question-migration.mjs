import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

const mc = JSON.parse(fs.readFileSync(path.join(root, 'src/data/multipleChoice.json'), 'utf8'));
const sa = JSON.parse(fs.readFileSync(path.join(root, 'src/data/shortAnswer.json'), 'utf8'));

function sqlEscape(str) {
  return str.replace(/'/g, "''");
}

function optionsJson(options) {
  return JSON.stringify(options).replace(/'/g, "''");
}

const mcInserts = mc.map(
  (q) =>
    `('v2-${sqlEscape(q.id)}', '${sqlEscape(q.question)}', 'multiple_choice', '${optionsJson(q.options)}'::jsonb, '${sqlEscape(q.category)}', true)`
);

const saInserts = sa.map(
  (q) =>
    `('v2-${sqlEscape(q.id)}', '${sqlEscape(q.question)}', 'short_answer', NULL, '${sqlEscape(q.category)}', true)`
);

const sql = `-- Expanded Vanchakan question bank (${mc.length} MC + ${sa.length} short answer)

ALTER TABLE questions ADD COLUMN IF NOT EXISTS external_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS questions_external_id_unique ON questions (external_id);

UPDATE questions SET is_active = false;

INSERT INTO questions (external_id, question_text, question_type, options, category, is_active)
VALUES
${[...mcInserts, ...saInserts].join(',\n')}
ON CONFLICT (external_id) DO UPDATE SET
  question_text = EXCLUDED.question_text,
  question_type = EXCLUDED.question_type,
  options = EXCLUDED.options,
  category = EXCLUDED.category,
  is_active = true;

-- Enforce readable short answers on evidence cards
CREATE OR REPLACE FUNCTION submit_answer(p_player_id UUID, p_session_token TEXT, p_answer_text TEXT)
RETURNS JSON AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_gq game_questions%ROWTYPE;
  v_answered INT;
  v_connected INT;
  v_qtype question_type;
  v_trimmed TEXT := trim(p_answer_text);
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'survey' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  SELECT * INTO v_gq FROM game_questions
  WHERE room_id = v_player.room_id AND question_order = v_room.current_question_index;

  IF v_gq.ends_at < now() THEN RAISE EXCEPTION 'TIME_EXPIRED'; END IF;

  SELECT question_type INTO v_qtype FROM questions WHERE id = v_gq.question_id;

  IF v_trimmed = '' THEN RAISE EXCEPTION 'EMPTY_ANSWER'; END IF;
  IF v_qtype = 'short_answer' AND char_length(v_trimmed) > 40 THEN
    RAISE EXCEPTION 'ANSWER_TOO_LONG';
  END IF;

  INSERT INTO player_answers (room_id, player_id, question_id, answer_text)
  VALUES (v_player.room_id, p_player_id, v_gq.question_id, v_trimmed)
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
    updated_at = now()
  WHERE id = v_player.room_id;

  PERFORM advance_survey_question(p_player_id, p_session_token, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
`;

const outPath = path.join(root, 'supabase/migrations/018_question_bank.sql');
fs.writeFileSync(outPath, sql);
console.log(`Wrote ${outPath} (${mc.length} MC + ${sa.length} SA questions)`);
