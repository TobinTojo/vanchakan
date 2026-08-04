import { useEffect, useRef } from 'react';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PhaseProgressBar } from '@/components/common/PhaseProgressBar';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { advanceCrimeToEvidence } from '@/services/gameService';

const CRIME_REVEAL_SECONDS = 6;

export function CrimeRevealView() {
  const { session, crime, room } = useGame();
  const { remaining, progress } = useSyncedGameTimer(CRIME_REVEAL_SECONDS, false);
  const advancingRef = useRef(false);

  useEffect(() => {
    if (!session || !room || room.status !== 'crime_reveal') return;

    const tryAdvance = () => {
      if (advancingRef.current) return;
      advancingRef.current = true;
      advanceCrimeToEvidence(session.playerId, session.sessionToken)
        .catch(() => {})
        .finally(() => {
          advancingRef.current = false;
        });
    };

    if (remaining <= 0) {
      tryAdvance();
      const interval = setInterval(tryAdvance, 2000);
      return () => clearInterval(interval);
    }
  }, [remaining, session, room?.status]);

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader phase="The Crime" title="A Terrible Deed Has Occurred" />

      <Card glow className="animate-reveal text-center">
        <div className="mb-4 text-5xl">🚨</div>
        <p className="text-xl font-display italic text-vanchakan-red">
          {crime?.crime_text ?? 'Investigating the scene...'}
        </p>
        <p className="mt-4 text-sm text-vanchakan-muted">
          Compiling witness statements into evidence cards...
        </p>
      </Card>

      <PhaseProgressBar
        progress={progress}
        label={
          remaining > 0
            ? `Gathering evidence in ${remaining}s...`
            : 'Opening evidence board...'
        }
      />
    </div>
  );
}
