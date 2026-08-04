import { useEffect } from 'react';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PhaseProgressBar } from '@/components/common/PhaseProgressBar';
import { WaitingScreen } from '@/components/common/WaitingScreen';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { advanceCrimeToEvidence } from '@/services/gameService';
import { shouldDrivePhaseAdvance } from '@/utils/phaseAdvance';

const ADVANCE_INTERVAL_MS = 4000;

/** Recovery screen if room is stuck in fake_evidence status */
export function FakeEvidenceView() {
  const { session, room, players, refreshRoom } = useGame();
  const { progress } = useSyncedGameTimer(3, false, true);
  const drivesAdvance = session ? shouldDrivePhaseAdvance(session.playerId, players) : false;

  useEffect(() => {
    if (!session || room?.status !== 'fake_evidence') return;

    const tryAdvance = () => {
      if (!drivesAdvance) {
        refreshRoom().catch(() => {});
        return;
      }
      advanceCrimeToEvidence(session.playerId, session.sessionToken)
        .then(() => refreshRoom())
        .catch(() => {});
    };

    tryAdvance();
    const interval = setInterval(tryAdvance, ADVANCE_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [session, room?.status, refreshRoom, drivesAdvance]);

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader phase="Evidence Lab" title="Compiling Evidence" />
      <WaitingScreen message="Building the evidence board..." />
      <PhaseProgressBar progress={progress} label="Opening evidence board..." />
    </div>
  );
}
