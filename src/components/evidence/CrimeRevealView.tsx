import { useEffect, useRef } from 'react';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PhaseProgressBar } from '@/components/common/PhaseProgressBar';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { advanceCrimeToEvidence } from '@/services/gameService';
import { shouldDrivePhaseAdvance } from '@/utils/phaseAdvance';

const CRIME_REVEAL_SECONDS = 6;
const ADVANCE_INTERVAL_MS = 4000;

export function CrimeRevealView() {
  const { session, crime, room, players, refreshRoom } = useGame();
  const { remaining, progress } = useSyncedGameTimer(CRIME_REVEAL_SECONDS, false, true);
  const advancingRef = useRef(false);
  const drivesAdvance = session ? shouldDrivePhaseAdvance(session.playerId, players) : false;

  useEffect(() => {
    if (!session || !room || room.status !== 'crime_reveal') return;

    const tryAdvance = () => {
      if (!drivesAdvance || advancingRef.current) return;
      advancingRef.current = true;
      advanceCrimeToEvidence(session.playerId, session.sessionToken)
        .then(() => refreshRoom())
        .catch(() => {})
        .finally(() => {
          advancingRef.current = false;
        });
    };

    if (remaining <= 0) {
      tryAdvance();
      const interval = setInterval(tryAdvance, ADVANCE_INTERVAL_MS);
      return () => clearInterval(interval);
    }
  }, [remaining, session, room?.status, refreshRoom, drivesAdvance]);

  useEffect(() => {
    if (!session || room?.status !== 'crime_reveal' || drivesAdvance) return;
    const interval = setInterval(() => refreshRoom().catch(() => {}), ADVANCE_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [session, room?.status, refreshRoom, drivesAdvance]);

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
