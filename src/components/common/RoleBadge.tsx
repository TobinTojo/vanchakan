import { useGame } from '@/context/GameContext';
import { cn } from '@/utils/storage';

const PHASES_WITH_ROLE = new Set([
  'role_reveal',
  'crime_reveal',
  'fake_evidence',
  'evidence',
  'interrogation',
  'lie_detector',
  'suspect_vote',
  'final_vote',
  'tie_breaker',
  'results',
  'finished',
]);

export function RoleBadge() {
  const { room, myRole } = useGame();

  if (!myRole || !room || !PHASES_WITH_ROLE.has(room.status)) return null;

  const isCriminal = myRole === 'criminal';

  return (
    <div
      className={cn(
        'fixed top-4 left-4 z-10 flex items-center gap-2 rounded-full border px-3 py-1.5 text-xs font-semibold shadow-lg',
        isCriminal
          ? 'border-vanchakan-red/50 bg-vanchakan-red/15 text-vanchakan-red'
          : 'border-vanchakan-gold/50 bg-vanchakan-gold/15 text-vanchakan-gold'
      )}
    >
      <span>{isCriminal ? '🎭' : '🔍'}</span>
      <span>{isCriminal ? 'You are the Vanchakan' : 'You are innocent'}</span>
    </div>
  );
}
