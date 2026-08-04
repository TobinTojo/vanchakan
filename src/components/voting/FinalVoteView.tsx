import { useEffect, useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { GameTimer } from '@/components/common/GameTimer';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PlayerList } from '@/components/common/PlayerList';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { submitFinalVote, hasSubmittedFinalVote, getSuspectVoteResults } from '@/services/gameService';
import { formatError } from '@/utils/storage';
import type { SuspectVoteResult } from '@/types';

export function FinalVoteView() {
  const { session, room, players } = useGame();
  const [finalists, setFinalists] = useState<SuspectVoteResult[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isTieBreaker = room?.status === 'tie_breaker';
  const { remaining } = useSyncedGameTimer(isTieBreaker ? 20 : 30);

  useEffect(() => {
    if (!session || !room) return;
    const tieBreaker = room.status === 'tie_breaker';
    hasSubmittedFinalVote(session.roomId, session.playerId, tieBreaker).then(setSubmitted);

    if (tieBreaker && room.tie_breaker_candidates) {
      setFinalists(
        room.tie_breaker_candidates.map((id) => {
          const p = players.find((pl) => pl.id === id);
          return { player_id: id, name: p?.display_name ?? 'Unknown', votes: 0, eliminated: false };
        })
      );
    } else {
      getSuspectVoteResults(session.roomId).then((results) => {
        setFinalists(results.filter((r) => !r.eliminated || r.votes > 0));
      });
    }
  }, [session, room, players]);

  const handleSubmit = async () => {
    if (!session || !selected) return;
    setLoading(true);
    try {
      await submitFinalVote(session.playerId, session.sessionToken, selected, isTieBreaker);
      setSubmitted(true);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  const eligiblePlayers = finalists.length > 0
    ? players.filter((p) => finalists.some((f) => f.player_id === p.id))
    : players.filter((p) => p.is_connected);

  if (submitted) {
    return (
      <div className="mx-auto max-w-lg text-center animate-fade-in">
        <PhaseHeader
          phase={isTieBreaker ? 'Tie Breaker' : 'Final Vote'}
          title="Vote Submitted"
          subtitle="The verdict is being decided..."
        />
        <GameTimer remaining={remaining} total={isTieBreaker ? 20 : 30} />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader
        phase={isTieBreaker ? 'Tie Breaker' : 'Final Vote'}
        title={isTieBreaker ? 'Break the Tie!' : 'Cast Your Final Vote'}
        subtitle="Who is the Vanchakan?"
      />

      <div className="mb-6 flex justify-center">
        <GameTimer remaining={remaining} total={isTieBreaker ? 20 : 30} />
      </div>

      <Card glow>
        <PlayerList
          players={eligiblePlayers}
          currentPlayerId={session?.playerId}
          excludeIds={session ? [session.playerId] : []}
          selectable
          selectedIds={selected ? [selected] : []}
          onSelect={setSelected}
          maxSelections={1}
        />
        <Button onClick={handleSubmit} disabled={!selected} loading={loading} variant="danger" className="mt-4 w-full" size="lg">
          Accuse Suspect
        </Button>
        {error && <p className="mt-2 text-sm text-vanchakan-red">{error}</p>}
      </Card>
    </div>
  );
}
