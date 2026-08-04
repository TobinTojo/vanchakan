import { useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { GameTimer } from '@/components/common/GameTimer';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { EvidenceCard } from '@/components/evidence/EvidenceCard';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { nextInterrogationRound, selectInterrogationTarget } from '@/services/gameService';
import { formatError } from '@/utils/storage';

export function InterrogationView() {
  const { session, room, players, evidence, interrogationRound, isHost } = useGame();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const targetSelected = Boolean(interrogationRound?.suspect_player_id);
  const { remaining } = useSyncedGameTimer(60, false, !targetSelected);

  if (!interrogationRound || !room) return null;

  const activeEvidence = evidence.find((e) => e.id === interrogationRound.evidence_id);
  const interrogator = players.find((p) => p.id === interrogationRound.interrogator_player_id);
  const suspect = players.find((p) => p.id === interrogationRound.suspect_player_id);
  const isInterrogator = session?.playerId === interrogationRound.interrogator_player_id;
  const isSuspect = session?.playerId === interrogationRound.suspect_player_id;
  const selectableTargets = players.filter(
    (p) => p.is_connected && p.id !== interrogationRound.interrogator_player_id
  );

  const handleSelectTarget = async (targetId: string) => {
    if (!session) return;
    setLoading(true);
    setError(null);
    try {
      await selectInterrogationTarget(session.playerId, session.sessionToken, targetId);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  const handleNextRound = async () => {
    if (!session) return;
    setLoading(true);
    setError(null);
    try {
      await nextInterrogationRound(session.playerId, session.sessionToken);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-xl animate-fade-in">
      <PhaseHeader
        phase="Interrogation"
        title={`Round ${room.current_round} of 6`}
        subtitle={
          targetSelected
            ? `Interrogator: ${interrogator?.display_name ?? 'Unknown'} · Suspect: ${suspect?.display_name ?? 'Unknown'}`
            : `${interrogator?.display_name ?? 'Someone'} will choose who to interrogate`
        }
      />

      {activeEvidence && (
        <div className="mb-6">
          <EvidenceCard evidence={activeEvidence} active showMatchCount />
        </div>
      )}

      {!targetSelected ? (
        <Card>
          {isInterrogator ? (
            <>
              <p className="mb-4 text-center text-vanchakan-muted">
                You were chosen to interrogate. Pick a player to question about this evidence:
              </p>
              <div className="grid gap-2">
                {selectableTargets.map((player) => (
                  <Button
                    key={player.id}
                    variant="secondary"
                    onClick={() => handleSelectTarget(player.id)}
                    loading={loading}
                    className="w-full justify-start"
                  >
                    {player.display_name}
                  </Button>
                ))}
              </div>
            </>
          ) : (
            <p className="text-center text-vanchakan-muted">
              Waiting for <strong className="text-white">{interrogator?.display_name}</strong> to choose
              who to interrogate...
            </p>
          )}
        </Card>
      ) : (
        <>
          <div className="mb-6 flex justify-center">
            <GameTimer remaining={remaining} total={60} label="Discussion time" />
          </div>

          <Card>
            {isSuspect ? (
              <p className="text-center text-vanchakan-muted">
                You are being questioned about this evidence. Defend yourself{' '}
                <strong className="text-white">verbally</strong> with your group.
              </p>
            ) : isInterrogator ? (
              <p className="text-center text-vanchakan-muted">
                Question <strong className="text-white">{suspect?.display_name}</strong> about this evidence.
                Use voice chat — everyone is listening.
              </p>
            ) : (
              <p className="text-center text-vanchakan-muted">
                Discuss with your group! Use voice chat while{' '}
                <strong className="text-white">{interrogator?.display_name}</strong> interrogates{' '}
                <strong className="text-white">{suspect?.display_name}</strong>.
              </p>
            )}
          </Card>
        </>
      )}

      {isHost && targetSelected && (
        <div className="mt-6 text-center">
          <Button onClick={handleNextRound} loading={loading}>
            {room.current_round >= 6 ? 'Proceed to Suspect Vote' : 'Next Round'}
          </Button>
        </div>
      )}

      {error && <p className="mt-4 text-sm text-vanchakan-red text-center">{error}</p>}
    </div>
  );
}
