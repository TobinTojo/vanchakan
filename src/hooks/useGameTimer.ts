import { useEffect, useState, useRef } from 'react';
import { useGame } from '@/context/GameContext';
import { gameTick } from '@/services/gameService';

export function useGameTimer(endsAt: string | null, serverOffsetMs = 0): number {
  const [remaining, setRemaining] = useState(0);

  useEffect(() => {
    if (!endsAt) {
      setRemaining(0);
      return;
    }

    const tick = () => {
      const now = Date.now() + serverOffsetMs;
      const diff = Math.max(0, Math.ceil((new Date(endsAt).getTime() - now) / 1000));
      setRemaining(diff);
    };

    tick();
    const interval = setInterval(tick, 250);
    return () => clearInterval(interval);
  }, [endsAt, serverOffsetMs]);

  return remaining;
}

/** Server-synced timer that triggers game_tick when time expires. */
export function useSyncedGameTimer(total = 30) {
  const { room, session, serverOffsetMs } = useGame();
  const remaining = useGameTimer(room?.phase_ends_at ?? null, serverOffsetMs);
  const lastTickedRef = useRef<string | null>(null);

  useEffect(() => {
    if (remaining > 0) {
      lastTickedRef.current = null;
      return;
    }
    if (!session || !room?.phase_ends_at) return;

    const key = `${room.status}-${room.phase_ends_at}`;
    if (lastTickedRef.current === key) return;
    lastTickedRef.current = key;

    gameTick(session.playerId, session.sessionToken).catch(() => {});
  }, [remaining, session, room?.status, room?.phase_ends_at]);

  return { remaining, total, endsAt: room?.phase_ends_at };
}

export function usePreviousPhaseWarning(remaining: number, threshold = 5): boolean {
  const [warned, setWarned] = useState(false);

  useEffect(() => {
    if (remaining <= threshold && remaining > 0 && !warned) {
      setWarned(true);
    }
    if (remaining > threshold) {
      setWarned(false);
    }
  }, [remaining, threshold, warned]);

  return remaining <= threshold && remaining > 0;
}
