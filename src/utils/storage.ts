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
  if (error && typeof error === 'object' && 'code' in error) {
    const code = String((error as { code?: string }).code);
    if (code === '23505') return 'Already submitted — waiting for others.';
  }
  if (error instanceof Error) {
    const msg = error.message;
    if (msg.includes('ROOM_NOT_FOUND')) return 'Room not found. Check the code and try again.';
    if (msg.includes('ROOM_FULL')) return 'This room is full (max 8 players).';
    if (msg.includes('GAME_ALREADY_STARTED')) return 'This game has already started.';
    if (msg.includes('DUPLICATE_NAME')) return 'That name is already taken in this room.';
    if (msg.includes('INVALID_SESSION')) return 'Session expired. Please rejoin the room.';
    if (msg.includes('NOT_HOST')) return 'Only the host can do that.';
    if (msg.includes('NOT_ENOUGH_PLAYERS')) return 'Need at least 3 players to start.';
    if (msg.includes('TIME_EXPIRED')) return 'Time expired for this question.';
    if (msg.includes('INVALID_VOTE')) return 'Invalid vote selection.';
    if (msg.includes('409') || msg.includes('23505')) return 'Already submitted — waiting for others.';
    return msg;
  }
  return 'Something went wrong. Please try again.';
}

export function cn(...classes: (string | boolean | undefined | null)[]): string {
  return classes.filter(Boolean).join(' ');
}
