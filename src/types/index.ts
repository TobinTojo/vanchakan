export type RoomStatus =
  | 'lobby'
  | 'survey'
  | 'role_reveal'
  | 'fake_evidence'
  | 'crime_reveal'
  | 'evidence'
  | 'interrogation'
  | 'lie_detector'
  | 'suspect_vote'
  | 'final_vote'
  | 'tie_breaker'
  | 'results'
  | 'finished';

export type QuestionType = 'multiple_choice' | 'short_answer';
export type PlayerRole = 'innocent' | 'criminal' | 'unknown';
export type LieDetectorAction = 'inspect_evidence' | 'check_answer';

export interface Room {
  id: string;
  room_code: string;
  host_player_id: string | null;
  status: RoomStatus;
  current_question_index: number;
  current_round: number;
  current_crime_id: string | null;
  lie_detector_event: number;
  phase_ends_at: string | null;
  tie_breaker_candidates: string[] | null;
  accused_player_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface Player {
  id: string;
  room_id: string;
  display_name: string;
  is_host: boolean;
  is_connected: boolean;
  joined_at: string;
  last_seen_at: string;
}

export interface Question {
  id: string;
  question_text: string;
  question_type: QuestionType;
  options: string[] | null;
  category: string | null;
}

export interface GameQuestion {
  id: string;
  room_id: string;
  question_id: string;
  question_order: number;
  started_at: string | null;
  ends_at: string | null;
}

export interface PlayerAnswer {
  id: string;
  room_id: string;
  player_id: string;
  question_id: string;
  answer_text: string;
  submitted_at: string;
}

export interface Crime {
  id: string;
  crime_text: string;
}

export interface Evidence {
  id: string;
  room_id: string;
  evidence_order: number;
  evidence_text: string;
  question_id?: string | null;
  question_text?: string | null;
  answer_text?: string | null;
  matching_count?: number;
  total_players?: number;
  is_inspected: boolean;
  inspection_result: string | null;
  created_at: string;
}

export interface EvidenceFull extends Evidence {
  is_fake: boolean;
  source_player_id: string | null;
  question_id: string | null;
}

export interface InterrogationRound {
  id: string;
  room_id: string;
  round_number: number;
  evidence_id: string;
  interrogator_player_id: string | null;
  suspect_player_id: string | null;
  suspect_response: string | null;
  started_at: string | null;
  ends_at: string | null;
  completed_at: string | null;
}

export interface LieDetectorVote {
  id: string;
  room_id: string;
  event_number: number;
  player_id: string;
  action_type: LieDetectorAction;
  target_evidence_id: string | null;
  target_player_id: string | null;
  target_question_id: string | null;
}

export interface SuspectVote {
  id: string;
  room_id: string;
  voter_player_id: string;
  suspect_player_id: string;
  vote_rank: number;
}

export interface FinalVote {
  id: string;
  room_id: string;
  voter_player_id: string;
  suspect_player_id: string;
  is_tie_breaker: boolean;
}

export interface GameResult {
  id: string;
  room_id: string;
  criminal_player_id: string | null;
  accused_player_id: string | null;
  fake_evidence_writer_id: string | null;
  winning_side: string | null;
}

export interface SessionData {
  playerId: string;
  roomId: string;
  sessionToken: string;
  displayName: string;
  roomCode: string;
}

export interface GameResultsData {
  criminal_id: string;
  accused_id: string;
  fake_writer_id: string;
  winning_side: 'detectives' | 'criminal';
  evidence: Array<{
    order: number;
    text: string;
    question_text?: string | null;
    answer_text?: string | null;
    is_fake: boolean;
    is_inspected: boolean;
    inspection_result: string | null;
  }>;
}

export interface SuspectVoteResult {
  player_id: string;
  name: string;
  votes: number;
  eliminated: boolean;
}

export interface FakeEvidenceTask {
  question_id: string;
  question_text: string;
  question_type: QuestionType;
  options: string[] | null;
}

export interface AnswerCount {
  answered: number;
  total: number;
}

export interface LieDetectorAnswerReveal {
  player_name: string;
  question: string;
  answer: string;
}

export interface LieDetectorResult {
  action_type: LieDetectorAction;
  player_name?: string | null;
  question_text?: string | null;
  answer_text?: string | null;
  inspection_result?: string | null;
  evidence_order?: number | null;
}
