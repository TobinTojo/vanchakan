import type { Player } from '@/types';

/** Only one client should drive timed phase advances to avoid RPC races. */
export function shouldDrivePhaseAdvance(playerId: string, players: Player[]): boolean {
  const connected = players.filter((p) => p.is_connected);
  if (connected.length === 0) return false;

  const host = connected.find((p) => p.is_host);
  if (host) return host.id === playerId;

  const leader = [...connected].sort((a, b) => a.id.localeCompare(b.id))[0];
  return leader?.id === playerId;
}
