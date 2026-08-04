import { useGame } from '@/context/GameContext';
import { cn } from '@/utils/storage';

const PHASES_WITH_ROLE = new Set([
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
        'flex shrink-0 items-center gap-1 rounded-full border px-2 py-1 text-[10px] font-semibold sm:gap-1.5 sm:px-2.5 sm:text-xs',
        isCriminal
          ? 'border-vanchakan-red/50 bg-vanchakan-red/15 text-vanchakan-red'
          : 'border-vanchakan-gold/50 bg-vanchakan-gold/15 text-vanchakan-gold'
      )}
    >
      <span className="leading-none">{isCriminal ? '🎭' : '🔍'}</span>
      <span className="leading-none">{isCriminal ? 'Vanchakan' : 'Innocent'}</span>
    </div>
  );
}
