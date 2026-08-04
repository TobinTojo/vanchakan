import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PhaseProgressBar } from '@/components/common/PhaseProgressBar';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';

const CRIME_REVEAL_SECONDS = 6;

export function CrimeRevealView() {
  const { crime } = useGame();
  const { remaining, progress } = useSyncedGameTimer(CRIME_REVEAL_SECONDS, true);

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader phase="The Crime" title="A Terrible Deed Has Occurred" />

      <Card glow className="animate-reveal text-center">
        <div className="mb-4 text-5xl">🚨</div>
        <p className="text-xl font-display italic text-vanchakan-red">
          {crime?.crime_text ?? 'Investigating the scene...'}
        </p>
        <p className="mt-4 text-sm text-vanchakan-muted">
          Evidence is being collected from witness statements...
        </p>
      </Card>

      <PhaseProgressBar
        progress={progress}
        label={remaining > 0 ? `Gathering evidence in ${remaining}s...` : 'Preparing evidence board...'}
      />
    </div>
  );
}
