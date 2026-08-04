import { supabase } from '@/lib/supabase';
import type {
  AnswerCount,
  FakeEvidenceTask,
  GameResultsData,
  LieDetectorAction,
  LieDetectorAnswerReveal,
  SuspectVoteResult,
} from '@/types';
import { generateSessionToken, isRpcConflict } from '@/utils/storage';

export async function createRoom(displayName: string) {
  const sessionToken = generateSessionToken();
  const { data, error } = await supabase.rpc('create_room', {
    p_display_name: displayName.trim(),
    p_session_token: sessionToken,
  });
  if (error) throw error;
  return { ...data, sessionToken } as {
    room_id: string;
    player_id: string;
    room_code: string;
    sessionToken: string;
  };
}

export async function joinRoom(roomCode: string, displayName: string) {
  const sessionToken = generateSessionToken();
  const { data, error } = await supabase.rpc('join_room', {
    p_room_code: roomCode.toUpperCase().trim(),
    p_display_name: displayName.trim(),
    p_session_token: sessionToken,
  });
  if (error) throw error;
  return { ...data, sessionToken } as {
    room_id: string;
    player_id: string;
    room_code: string;
    sessionToken: string;
  };
}

export async function reconnectPlayer(playerId: string, sessionToken: string) {
  const { data, error } = await supabase.rpc('reconnect_player', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error) throw error;
  return data;
}

export async function leaveRoom(playerId: string, sessionToken: string) {
  const { error } = await supabase.rpc('leave_room', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error) throw error;
}

export async function heartbeat(playerId: string, sessionToken: string) {
  await supabase.rpc('player_heartbeat', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
}

export async function startGame(playerId: string, sessionToken: string) {
  const { error } = await supabase.rpc('start_game', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error) throw error;
}

export async function submitAnswer(playerId: string, sessionToken: string, answerText: string) {
  const { data, error } = await supabase.rpc('submit_answer', {
    p_player_id: playerId,
    p_session_token: sessionToken,
    p_answer_text: answerText,
  });
  if (error) throw error;
  return data as AnswerCount;
}

export async function getMyRole(playerId: string, sessionToken: string): Promise<string> {
  const { data, error } = await supabase.rpc('get_my_role', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error) throw error;
  return data as string;
}

export async function getFakeEvidenceTask(playerId: string, sessionToken: string): Promise<FakeEvidenceTask | null> {
  const { data, error } = await supabase.rpc('get_fake_evidence_task', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error) throw error;
  return data as FakeEvidenceTask | null;
}

export async function submitFakeEvidence(playerId: string, sessionToken: string, answerText: string) {
  const { error } = await supabase.rpc('submit_fake_evidence', {
    p_player_id: playerId,
    p_session_token: sessionToken,
    p_answer_text: answerText,
  });
  if (error && !isRpcConflict(error)) throw error;
}

export async function startInterrogation(playerId: string, sessionToken: string) {
  const { error } = await supabase.rpc('start_interrogation', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error) throw error;
}

export async function submitInterrogationResponse(playerId: string, sessionToken: string, response: string) {
  const { error } = await supabase.rpc('submit_interrogation_response', {
    p_player_id: playerId,
    p_session_token: sessionToken,
    p_response: response,
  });
  if (error) throw error;
}

export async function nextInterrogationRound(playerId: string, sessionToken: string) {
  const { error } = await supabase.rpc('next_interrogation_round', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error) throw error;
}

export async function submitLieDetectorVote(
  playerId: string,
  sessionToken: string,
  action: LieDetectorAction,
  targets: {
    evidenceId?: string;
    playerId?: string;
    questionId?: string;
  }
) {
  const { error } = await supabase.rpc('submit_lie_detector_vote', {
    p_player_id: playerId,
    p_session_token: sessionToken,
    p_action: action,
    p_target_evidence_id: targets.evidenceId ?? null,
    p_target_player_id: targets.playerId ?? null,
    p_target_question_id: targets.questionId ?? null,
  });
  if (error) throw error;
}

export async function submitSuspectVotes(
  playerId: string,
  sessionToken: string,
  suspect1: string,
  suspect2: string
) {
  const { error } = await supabase.rpc('submit_suspect_votes', {
    p_player_id: playerId,
    p_session_token: sessionToken,
    p_suspect1: suspect1,
    p_suspect2: suspect2,
  });
  if (error) throw error;
}

export async function submitFinalVote(
  playerId: string,
  sessionToken: string,
  suspectId: string,
  isTieBreaker = false
) {
  const { error } = await supabase.rpc('submit_final_vote', {
    p_player_id: playerId,
    p_session_token: sessionToken,
    p_suspect_id: suspectId,
    p_is_tie_breaker: isTieBreaker,
  });
  if (error) throw error;
}

export async function getGameResults(playerId: string, sessionToken: string): Promise<GameResultsData> {
  const { data, error } = await supabase.rpc('get_game_results', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error) throw error;
  return data as GameResultsData;
}

export async function playAgain(playerId: string, sessionToken: string) {
  const { error } = await supabase.rpc('play_again', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error) throw error;
}

export async function gameTick(playerId: string, sessionToken: string) {
  const { error } = await supabase.rpc('game_tick', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  // 409 = another client already advanced the phase — safe to ignore
  if (error && !isRpcConflict(error)) {
    throw error;
  }
}

export async function getAnswerCount(roomId: string): Promise<AnswerCount> {
  const { data, error } = await supabase.rpc('get_answer_count', { p_room_id: roomId });
  if (error) throw error;
  return data as AnswerCount;
}

export async function getSuspectVoteResults(roomId: string): Promise<SuspectVoteResult[]> {
  const { data, error } = await supabase.rpc('get_suspect_vote_results', { p_room_id: roomId });
  if (error) throw error;
  return data as SuspectVoteResult[];
}

export async function getLieDetectorAnswer(roomId: string, eventNumber: number): Promise<LieDetectorAnswerReveal | null> {
  const { data, error } = await supabase.rpc('get_lie_detector_answer', {
    p_room_id: roomId,
    p_event_number: eventNumber,
  });
  if (error) throw error;
  return data as LieDetectorAnswerReveal | null;
}

export async function advanceCrimeToEvidence(playerId: string, sessionToken: string) {
  const { error } = await supabase.rpc('advance_crime_to_evidence', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error && !isRpcConflict(error)) throw error;
}

export async function advanceRoleRevealNow(playerId: string, sessionToken: string) {
  const { error } = await supabase.rpc('advance_role_reveal_now', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
  if (error && !isRpcConflict(error)) throw error;
}

export async function tryAdvanceSurveyIfReady(playerId: string, sessionToken: string) {
  await supabase.rpc('try_advance_survey_if_ready', {
    p_player_id: playerId,
    p_session_token: sessionToken,
  });
}

export async function fetchServerTimeOffset(): Promise<number> {
  const t0 = Date.now();
  const { data, error } = await supabase.rpc('get_server_time');
  const t1 = Date.now();
  if (error || !data) return 0;
  const serverMs = new Date(data as string).getTime();
  return serverMs - (t0 + t1) / 2;
}

export async function fetchRoom(roomId: string) {
  const { data, error } = await supabase.from('rooms').select('*').eq('id', roomId).single();
  if (error) throw error;
  return data;
}

export async function fetchPlayers(roomId: string) {
  const { data, error } = await supabase
    .from('players')
    .select('id, room_id, display_name, is_host, is_connected, joined_at, last_seen_at')
    .eq('room_id', roomId)
    .order('joined_at');
  if (error) throw error;
  return data;
}

export async function fetchCurrentGameQuestion(roomId: string, questionIndex: number) {
  const { data: gq, error: gqError } = await supabase
    .from('game_questions')
    .select('*')
    .eq('room_id', roomId)
    .eq('question_order', questionIndex)
    .single();
  if (gqError) throw gqError;

  const { data: question, error: qError } = await supabase
    .from('questions')
    .select('*')
    .eq('id', gq.question_id)
    .single();
  if (qError) throw qError;

  return { gameQuestion: gq, question };
}

export async function fetchEvidence(roomId: string) {
  const { data, error } = await supabase
    .from('evidence')
    .select('id, room_id, evidence_order, evidence_text, is_inspected, inspection_result, created_at')
    .eq('room_id', roomId)
    .order('evidence_order');
  if (error) throw error;
  return data;
}

export async function fetchCrime(crimeId: string) {
  const { data, error } = await supabase.from('crimes').select('*').eq('id', crimeId).single();
  if (error) throw error;
  return data;
}

export async function fetchInterrogationRound(roomId: string, roundNumber: number) {
  const { data, error } = await supabase
    .from('interrogation_rounds')
    .select('*')
    .eq('room_id', roomId)
    .eq('round_number', roundNumber)
    .single();
  if (error) throw error;
  return data;
}

export async function fetchGameQuestions(roomId: string) {
  const { data, error } = await supabase
    .from('game_questions')
    .select('*, questions(*)')
    .eq('room_id', roomId)
    .order('question_order');
  if (error) throw error;
  return data;
}

export async function fetchMyAnswer(roomId: string, playerId: string, questionId: string) {
  const { data } = await supabase
    .from('player_answers')
    .select('*')
    .eq('room_id', roomId)
    .eq('player_id', playerId)
    .eq('question_id', questionId)
    .maybeSingle();
  return data;
}

export async function hasSubmittedSuspectVotes(roomId: string, playerId: string) {
  const { count } = await supabase
    .from('suspect_votes')
    .select('*', { count: 'exact', head: true })
    .eq('room_id', roomId)
    .eq('voter_player_id', playerId);
  return (count ?? 0) > 0;
}

export async function hasSubmittedFinalVote(roomId: string, playerId: string, isTieBreaker: boolean) {
  const { count } = await supabase
    .from('final_votes')
    .select('*', { count: 'exact', head: true })
    .eq('room_id', roomId)
    .eq('voter_player_id', playerId)
    .eq('is_tie_breaker', isTieBreaker);
  return (count ?? 0) > 0;
}

export async function hasSubmittedLieDetectorVote(roomId: string, playerId: string, eventNumber: number) {
  const { count } = await supabase
    .from('lie_detector_votes')
    .select('*', { count: 'exact', head: true })
    .eq('room_id', roomId)
    .eq('player_id', playerId)
    .eq('event_number', eventNumber);
  return (count ?? 0) > 0;
}
