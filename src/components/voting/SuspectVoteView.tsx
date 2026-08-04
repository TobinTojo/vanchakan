import { useEffect, useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { GameTimer } from '@/components/common/GameTimer';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PlayerList } from '@/components/common/PlayerList';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { submitSuspectVotes, hasSubmittedSuspectVotes, getSuspectVoteResults } from '@/services/gameService';
import { formatError } from '@/utils/storage';
import type { SuspectVoteResult } from '@/types';
import { cn } from '@/utils/storage';

export function SuspectVoteView() {
  const { session, room, players } = useGame();
  const [selected, setSelected] = useState<string[]>([]);
  const [submitted, setSubmitted] = useState(false);
  const [results, setResults] = useState<SuspectVoteResult[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { remaining } = useSyncedGameTimer(45);

  useEffect(() => {
    if (!session || !room) return;
    hasSubmittedSuspectVotes(session.roomId, session.playerId).then(setSubmitted);
  }, [session, room]);

  useEffect(() => {
    if (!session || room?.status !== 'final_vote') return;
    getSuspectVoteResults(session.roomId).then(setResults);
  }, [session, room?.status]);

  const toggleSelect = (id: string) => {
    setSelected((prev) => {
      if (prev.includes(id)) return prev.filter((x) => x !== id);
      if (prev.length >= 2) return prev;
      return [...prev, id];
    });
  };

  const handleSubmit = async () => {
    if (!session || selected.length !== 2) return;
    setLoading(true);
    try {
      await submitSuspectVotes(session.playerId, session.sessionToken, selected[0], selected[1]);
      setSubmitted(true);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  if (results) {
    return (
      <div className="mx-auto max-w-lg animate-fade-in">
        <PhaseHeader phase="Suspect Vote" title="Vote Results" />
        <div className="space-y-2">
          {results.map((r) => (
            <div
              key={r.player_id}
              className={cn(
                'flex items-center justify-between rounded-lg border px-4 py-3',
                r.eliminated ? 'border-vanchakan-border opacity-50' : 'border-vanchakan-gold/50'
              )}
            >
              <span className="text-white">{r.name}</span>
              <div className="flex items-center gap-2">
                <span className="text-vanchakan-gold font-bold">{r.votes} votes</span>
                <span className={cn('text-xs', r.eliminated ? 'text-vanchakan-muted' : 'text-green-400')}>
                  {r.eliminated ? 'Eliminated' : 'Finalist'}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (submitted) {
    return (
      <div className="mx-auto max-w-lg text-center animate-fade-in">
        <PhaseHeader phase="Suspect Vote" title="Votes Locked" subtitle="Waiting for all players..." />
        <GameTimer remaining={remaining} total={45} />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader
        phase="Suspect Vote"
        title="Top Two Suspects"
        subtitle="Select exactly 2 players you suspect most (not yourself)"
      />

      <div className="mb-6 flex justify-center">
        <GameTimer remaining={remaining} total={45} />
      </div>

      <Card>
        <PlayerList
          players={players.filter((p) => p.is_connected)}
          currentPlayerId={session?.playerId}
          excludeIds={session ? [session.playerId] : []}
          selectable
          selectedIds={selected}
          onSelect={toggleSelect}
          maxSelections={2}
        />
        <p className="mt-3 text-center text-sm text-vanchakan-muted">
          {selected.length}/2 selected
        </p>
        <Button
          onClick={handleSubmit}
          disabled={selected.length !== 2}
          loading={loading}
          className="mt-4 w-full"
        >
          Submit Votes
        </Button>
        {error && <p className="mt-2 text-sm text-vanchakan-red">{error}</p>}
      </Card>
    </div>
  );
}
