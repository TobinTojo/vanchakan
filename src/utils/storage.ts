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
