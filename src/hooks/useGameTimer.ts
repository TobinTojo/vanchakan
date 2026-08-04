import { useEffect, useState, useCallback, useRef } from 'react';

export function useGameTimer(endsAt: string | null): number {
  const [remaining, setRemaining] = useState(0);

  useEffect(() => {
    if (!endsAt) {
      setRemaining(0);
      return;
    }

    const tick = () => {
      const diff = Math.max(0, Math.ceil((new Date(endsAt).getTime() - Date.now()) / 1000));
      setRemaining(diff);
    };

    tick();
    const interval = setInterval(tick, 250);
    return () => clearInterval(interval);
  }, [endsAt]);

  return remaining;
}

export function useInterval(callback: () => void, delay: number | null): void {
  const savedCallback = useRef(callback);

  useEffect(() => {
    savedCallback.current = callback;
  }, [callback]);

  useEffect(() => {
    if (delay === null) return;
    const id = setInterval(() => savedCallback.current(), delay);
    return () => clearInterval(id);
  }, [delay]);
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

export function useAsyncAction<T extends unknown[]>(
  action: (...args: T) => Promise<void>
): { execute: (...args: T) => Promise<void>; loading: boolean; error: string | null } {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const execute = useCallback(
    async (...args: T) => {
      setLoading(true);
      setError(null);
      try {
        await action(...args);
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Unknown error');
        throw e;
      } finally {
        setLoading(false);
      }
    },
    [action]
  );

  return { execute, loading, error };
}
