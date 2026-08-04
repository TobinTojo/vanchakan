import { isDevMode } from '@/lib/supabase';
import { useGame } from '@/context/GameContext';
import { gameTick } from '@/services/gameService';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';

export function DevPanel() {
  const { session, room, players, evidence, myRole } = useGame();

  if (!isDevMode || !session) return null;

  const handleTick = () => gameTick(session.playerId, session.sessionToken);

  return (
    <div className="fixed bottom-4 right-4 z-50 max-w-xs">
      <Card className="border-yellow-500/50 bg-yellow-900/20 p-4 text-xs">
        <p className="font-bold text-yellow-400 mb-2">DEV MODE</p>
        <p className="text-vanchakan-muted mb-1">Phase: {room?.status}</p>
        <p className="text-vanchakan-muted mb-1">Role: {myRole ?? 'unknown'}</p>
        <p className="text-vanchakan-muted mb-1">Players: {players.length}</p>
        <p className="text-vanchakan-muted mb-2">Evidence: {evidence.length}</p>
        <Button size="sm" variant="secondary" onClick={handleTick} className="w-full">
          Force Game Tick
        </Button>
      </Card>
    </div>
  );
}
