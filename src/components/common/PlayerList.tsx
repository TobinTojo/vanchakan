import type { Player } from '@/types';
import { cn } from '@/utils/storage';

interface PlayerListProps {
  players: Player[];
  currentPlayerId?: string;
  showStatus?: boolean;
  selectable?: boolean;
  selectedIds?: string[];
  onSelect?: (playerId: string) => void;
  excludeIds?: string[];
  maxSelections?: number;
}

export function PlayerList({
  players,
  currentPlayerId,
  showStatus = true,
  selectable = false,
  selectedIds = [],
  onSelect,
  excludeIds = [],
  maxSelections = 1,
}: PlayerListProps) {
  const filtered = players.filter((p) => !excludeIds.includes(p.id));

  return (
    <ul className="space-y-2" role="list" aria-label="Players">
      {filtered.map((player) => {
        const isSelected = selectedIds.includes(player.id);
        const isMe = player.id === currentPlayerId;
        const canSelect = selectable && onSelect && (!maxSelections || selectedIds.length < maxSelections || isSelected);

        return (
          <li key={player.id}>
            <button
              type="button"
              disabled={!canSelect && selectable && !isSelected}
              onClick={() => canSelect && onSelect?.(player.id)}
              className={cn(
                'flex w-full items-center gap-3 rounded-lg border px-4 py-3 text-left transition-all',
                'focus:outline-none focus:ring-2 focus:ring-vanchakan-purple',
                isSelected
                  ? 'border-vanchakan-purple bg-vanchakan-purple/20'
                  : 'border-vanchakan-border bg-vanchakan-surface hover:border-vanchakan-purple/50',
                !canSelect && selectable && !isSelected && 'opacity-40 cursor-not-allowed'
              )}
              aria-pressed={isSelected}
            >
              <span
                className={cn(
                  'h-2.5 w-2.5 rounded-full',
                  player.is_connected ? 'bg-green-500' : 'bg-gray-500'
                )}
                aria-label={player.is_connected ? 'Connected' : 'Disconnected'}
              />
              <span className="flex-1 font-medium text-white">
                {player.display_name}
                {isMe && <span className="ml-2 text-xs text-vanchakan-muted">(you)</span>}
              </span>
              {player.is_host && (
                <span className="rounded-full bg-vanchakan-gold/20 px-2 py-0.5 text-xs font-semibold text-vanchakan-gold">
                  Host
                </span>
              )}
              {showStatus && !player.is_connected && (
                <span className="text-xs text-vanchakan-muted">Away</span>
              )}
            </button>
          </li>
        );
      })}
    </ul>
  );
}
