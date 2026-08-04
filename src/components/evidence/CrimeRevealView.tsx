import { useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { ART } from '@/assets/art';
import { useGame } from '@/context/GameContext';
import { advanceCrimeToEvidence } from '@/services/gameService';
import { formatError } from '@/utils/storage';

export function CrimeRevealView() {
  const { session, crime, room, isHost, refreshRoom } = useGame();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleContinue = async () => {
    if (!session) return;
    setLoading(true);
    setError(null);
    try {
      await advanceCrimeToEvidence(session.playerId, session.sessionToken);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
    await refreshRoom();
  };

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader phase="The Crime" title="A Terrible Deed Has Occurred" />

      <Card glow className="animate-reveal overflow-hidden text-center">
        <div className="relative -mx-5 -mt-5 mb-5 sm:-mx-6 sm:-mt-6">
          <img
            src={ART.crimeScene}
            alt=""
            className="aspect-[16/9] w-full object-cover"
          />
          <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-vanchakan-card via-vanchakan-card/40 to-transparent" />
        </div>
        <p className="text-xl font-display italic text-vanchakan-red">
          {crime?.crime_text ?? 'Investigating the scene...'}
        </p>
        <p className="mt-4 text-sm text-vanchakan-muted">
          Survey answers will be compiled into evidence cards.
        </p>
      </Card>

      {room?.status === 'crime_reveal' && (
        <div className="mt-6">
          {isHost ? (
            <>
              <Button onClick={handleContinue} loading={loading} size="lg" className="w-full">
                Open Evidence Board
              </Button>
              {error && <p className="mt-2 text-center text-sm text-vanchakan-red">{error}</p>}
            </>
          ) : (
            <p className="text-center text-sm text-vanchakan-muted">
              Waiting for the host to continue...
            </p>
          )}
        </div>
      )}
    </div>
  );
}
