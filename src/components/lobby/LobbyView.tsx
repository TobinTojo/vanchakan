import { useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { RoomCodeCard } from '@/components/common/RoomCodeCard';
import { PlayerList } from '@/components/common/PlayerList';
import { useGame } from '@/context/GameContext';
import { startGame, leaveRoom } from '@/services/gameService';
import { formatError } from '@/utils/storage';

export function LobbyView() {
  const { session, room, players, isHost } = useGame();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!session || !room) return null;

  const connectedCount = players.filter((p) => p.is_connected).length;
  const canStart = connectedCount >= 3;

  const handleStart = async () => {
    setLoading(true);
    setError(null);
    try {
      await startGame(session.playerId, session.sessionToken);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  const handleLeave = async () => {
    try {
      await leaveRoom(session.playerId, session.sessionToken);
    } catch {
      // ignore
    }
    window.location.href = '/';
  };

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <RoomCodeCard roomCode={room.room_code} />

      <Card className="mt-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">Players</h2>
          <span className="text-sm text-vanchakan-muted">{connectedCount}/8</span>
        </div>

        <PlayerList players={players} currentPlayerId={session.playerId} />

        {!canStart && (
          <p className="mt-4 text-center text-sm text-vanchakan-muted">
            Need at least 3 players to start
          </p>
        )}

        {error && <p className="mt-4 text-center text-sm text-vanchakan-red">{error}</p>}

        <div className="mt-6 flex flex-col gap-3">
          {isHost && (
            <Button onClick={handleStart} disabled={!canStart} loading={loading} size="lg" className="w-full">
              Start Game
            </Button>
          )}
          {!isHost && (
            <p className="text-center text-vanchakan-muted">Waiting for host to start the game...</p>
          )}
          <Button variant="ghost" onClick={handleLeave} className="w-full">
            Leave Room
          </Button>
        </div>
      </Card>
    </div>
  );
}
