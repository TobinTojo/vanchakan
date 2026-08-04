const SESSION_KEY = 'vanchakan_session';
const SOUND_KEY = 'vanchakan_sound_muted';

export function generateSessionToken(): string {
  return crypto.randomUUID() + '-' + crypto.randomUUID();
}

export function getSoundMuted(): boolean {
  return localStorage.getItem(SOUND_KEY) === 'true';
}

export function setSoundMuted(muted: boolean): void {
  localStorage.setItem(SOUND_KEY, muted ? 'true' : 'false');
}

export interface StoredSession {
  playerId: string;
  roomId: string;
  sessionToken: string;
  displayName: string;
  roomCode: string;
}

export function saveSession(session: StoredSession): void {
  localStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

export function getSession(): StoredSession | null {
  const raw = localStorage.getItem(SESSION_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as StoredSession;
  } catch {
    return null;
  }
}

export function clearSession(): void {
  localStorage.removeItem(SESSION_KEY);
}

export function getInviteLink(roomCode: string): string {
  const base = window.location.origin;
  return `${base}/join/${roomCode}`;
}

export function copyToClipboard(text: string): Promise<void> {
  return navigator.clipboard.writeText(text);
}

export function formatError(error: unknown): string {
  const text = extractErrorText(error);

  if (text.includes('ROOM_NOT_FOUND')) return 'Room not found. Check the code and try again.';
  if (text.includes('ROOM_FULL')) return 'This room is full (max 8 players).';
  if (text.includes('GAME_ALREADY_STARTED')) return 'This game has already started.';
  if (text.includes('DUPLICATE_NAME')) return 'That name is already taken in this room.';
  if (text.includes('INVALID_SESSION')) return 'Session expired. Please leave and rejoin the room.';
  if (text.includes('NOT_HOST')) return 'Only the host can start the game.';
  if (text.includes('NOT_ENOUGH_PLAYERS')) return 'Need at least 3 connected players to start.';
  if (text.includes('INVALID_STATE')) return 'The game is not in the lobby. Try leaving and rejoining.';
  if (text.includes('MISSING_QUESTIONS')) return 'Question database not set up. Run seed migration in Supabase.';
  if (text.includes('TIME_EXPIRED')) return 'Time expired for this question.';
  if (text.includes('INVALID_VOTE')) return 'Invalid vote selection.';
  if (text.includes('NOT_INTERROGATOR')) return 'Only the assigned interrogator can choose a target.';
  if (text.includes('CANNOT_INTERROGATE_SELF')) return 'You cannot interrogate yourself.';
  if (text.includes('INVALID_TARGET')) return 'Invalid player selected.';
  if (text.includes('409') || text.includes('23505')) return 'Already submitted — waiting for others.';

  if (text) return text;
  return 'Something went wrong. Please try again.';
}

function extractErrorText(error: unknown): string {
  if (!error || typeof error !== 'object') return '';

  const err = error as {
    message?: string;
    details?: string;
    hint?: string;
    code?: string;
  };

  if (err.code === '23505') return '23505';

  return [err.message, err.details, err.hint].filter(Boolean).join(' ');
}

/** Benign race when multiple clients advance the same phase at once. */
export function isRpcConflict(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const err = error as { code?: string; message?: string; status?: number };
  if (err.code === '23505' || err.code === '40001' || err.code === '40P01') return true;
  if (err.status === 409) return true;
  const text = [err.message].filter(Boolean).join(' ');
  return text.includes('409') || text.includes('23505') || text.includes('conflict');
}

export function cn(...classes: (string | boolean | undefined | null)[]): string {
  return classes.filter(Boolean).join(' ');
}
