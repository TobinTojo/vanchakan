import { useEffect } from 'react';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PhaseProgressBar } from '@/components/common/PhaseProgressBar';
import { WaitingScreen } from '@/components/common/WaitingScreen';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { advanceCrimeToEvidence } from '@/services/gameService';

/** Recovery screen if room is stuck in fake_evidence status */
export function FakeEvidenceView() {
  const { session, refreshRoom } = useGame();
  const { progress } = useSyncedGameTimer(3, false);

  useEffect(() => {
    if (!session) return;
    const tryAdvance = () =>
      advanceCrimeToEvidence(session.playerId, session.sessionToken)
        .then(() => refreshRoom())
        .catch(() => {});

    tryAdvance();
    const interval = setInterval(tryAdvance, 2000);
    return () => clearInterval(interval);
  }, [session, refreshRoom]);

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader phase="Evidence Lab" title="Compiling Evidence" />
      <WaitingScreen message="Building the evidence board..." />
      <PhaseProgressBar progress={progress} label="Opening evidence board..." />
    </div>
  );
}
