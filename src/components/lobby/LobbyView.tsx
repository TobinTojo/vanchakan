import { useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { RoomCodeCard } from '@/components/common/RoomCodeCard';
import { PlayerList } from '@/components/common/PlayerList';
import { ART } from '@/assets/art';
import { useGame } from '@/context/GameContext';
import { startGame, leaveRoom, setJesterEnabled } from '@/services/gameService';
import { cn, formatError } from '@/utils/storage';

export function LobbyView() {
  const { session, room, players, isHost } = useGame();
  const [loading, setLoading] = useState(false);
  const [toggleLoading, setToggleLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!session || !room) return null;

  const connectedCount = players.filter((p) => p.is_connected).length;
  const canStart = connectedCount >= 3;
  const jesterEnabled = room.jester_enabled ?? false;
  const jesterNeedsMore = jesterEnabled && connectedCount < 4;

  const handleStart = async () => {
    setLoading(true);
    setError(null);
    try {
      await startGame(session.playerId, session.sessionToken);
    } catch (e) {
      console.error('start_game failed:', e);
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  const handleJesterToggle = async () => {
    setToggleLoading(true);
    setError(null);
    try {
      await setJesterEnabled(session.playerId, session.sessionToken, !jesterEnabled);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setToggleLoading(false);
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

        {isHost && (
          <div className="mt-6 rounded-lg border border-vanchakan-border bg-vanchakan-surface/50 p-4">
            <div className="flex items-start gap-3">
              <img
                src={ART.roleJester}
                alt=""
                className="h-14 w-14 shrink-0 rounded-xl object-cover ring-1 ring-white/10"
              />
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="font-semibold text-white">Jester role</p>
                    <p className="text-xs text-vanchakan-muted">Optional neutral — wins alone if voted out</p>
                  </div>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={jesterEnabled}
                    disabled={toggleLoading}
                    onClick={handleJesterToggle}
                    className={cn(
                      'relative h-7 w-12 shrink-0 rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-vanchakan-purple',
                      jesterEnabled ? 'bg-vanchakan-purple' : 'bg-vanchakan-border',
                      toggleLoading && 'opacity-60'
                    )}
                  >
                    <span
                      className={cn(
                        'absolute top-0.5 h-6 w-6 rounded-full bg-white transition-transform',
                        jesterEnabled ? 'left-[22px]' : 'left-0.5'
                      )}
                    />
                  </button>
                </div>
                {jesterEnabled && (
                  <p className="mt-2 text-xs text-vanchakan-muted">
                    Needs 4+ players. The Jester wants the final vote — detectives and Vanchakan both lose.
                  </p>
                )}
              </div>
            </div>
          </div>
        )}

        {!isHost && jesterEnabled && (
          <p className="mt-4 text-center text-sm text-vanchakan-purple-light">
            Jester role enabled — someone may be playing for chaos.
          </p>
        )}

        {!canStart && (
          <p className="mt-4 text-center text-sm text-vanchakan-muted">
            Need at least 3 players to start
          </p>
        )}

        {jesterNeedsMore && (
          <p className="mt-4 text-center text-sm text-vanchakan-gold">
            Add one more player to start with the Jester enabled
          </p>
        )}

        {error && <p className="mt-4 text-center text-sm text-vanchakan-red">{error}</p>}

        <div className="mt-6 flex flex-col gap-3">
          {isHost && (
            <Button
              onClick={handleStart}
              disabled={!canStart || jesterNeedsMore}
              loading={loading}
              size="lg"
              className="w-full"
            >
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
