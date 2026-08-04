import { useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { GameTimer } from '@/components/common/GameTimer';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { submitInterrogationResponse, nextInterrogationRound } from '@/services/gameService';
import { formatError } from '@/utils/storage';

export function InterrogationView() {
  const { session, room, players, evidence, interrogationRound, isHost } = useGame();
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { remaining } = useSyncedGameTimer(60);

  if (!interrogationRound || !room) return null;

  const activeEvidence = evidence.find((e) => e.id === interrogationRound.evidence_id);
  const suspect = players.find((p) => p.id === interrogationRound.suspect_player_id);
  const isSuspect = session?.playerId === interrogationRound.suspect_player_id;

  const handleSubmitResponse = async () => {
    if (!session || !response.trim()) return;
    setLoading(true);
    try {
      await submitInterrogationResponse(session.playerId, session.sessionToken, response);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  const handleNextRound = async () => {
    if (!session) return;
    setLoading(true);
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
        subtitle={`Suspect: ${suspect?.display_name ?? 'Unknown'}`}
      />

      <div className="mb-6 flex justify-center">
        <GameTimer remaining={remaining} total={60} label="Discussion time" />
      </div>

      {activeEvidence && (
        <Card glow className="mb-6">
          <p className="text-xs font-bold uppercase text-vanchakan-gold mb-2">
            Active Evidence #{activeEvidence.evidence_order}
          </p>
          <p className="text-white">{activeEvidence.evidence_text}</p>
        </Card>
      )}

      {isSuspect ? (
        <Card>
          <p className="mb-3 text-sm text-vanchakan-muted">You are being questioned. Defend yourself:</p>
          <textarea
            value={response}
            onChange={(e) => setResponse(e.target.value)}
            placeholder="This does not describe me because..."
            maxLength={300}
            rows={3}
            className="w-full rounded-lg border border-vanchakan-border bg-vanchakan-surface px-4 py-3 text-white focus:border-vanchakan-purple focus:outline-none resize-none"
            aria-label="Your defense"
          />
          <Button onClick={handleSubmitResponse} disabled={!response.trim()} loading={loading} className="mt-3 w-full">
            Submit Defense
          </Button>
        </Card>
      ) : (
        <Card>
          <p className="text-vanchakan-muted text-center">
            Discuss with your group! Use voice chat to interrogate <strong className="text-white">{suspect?.display_name}</strong>.
          </p>
          {interrogationRound.suspect_response && (
            <div className="mt-4 rounded-lg bg-vanchakan-surface p-3 border border-vanchakan-border">
              <p className="text-xs text-vanchakan-muted mb-1">Suspect's response:</p>
              <p className="text-white italic">"{interrogationRound.suspect_response}"</p>
            </div>
          )}
        </Card>
      )}

      {isHost && (
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
