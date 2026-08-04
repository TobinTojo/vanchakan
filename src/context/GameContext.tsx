import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  useRef,
  type ReactNode,
} from 'react';
import { supabase } from '@/lib/supabase';
import type {
  Room,
  Player,
  Evidence,
  InterrogationRound,
  Crime,
  SessionData,
} from '@/types';
import {
  heartbeat,
  gameTick,
  fetchRoom,
  fetchPlayers,
  fetchEvidence,
  fetchCrime,
  fetchInterrogationRound,
  reconnectPlayer,
} from '@/services/gameService';
import { getSession, saveSession, clearSession } from '@/utils/storage';

interface GameContextValue {
  session: SessionData | null;
  room: Room | null;
  players: Player[];
  evidence: Evidence[];
  crime: Crime | null;
  interrogationRound: InterrogationRound | null;
  myRole: string | null;
  loading: boolean;
  error: string | null;
  setSession: (s: SessionData) => void;
  setMyRole: (role: string) => void;
  refreshRoom: () => Promise<void>;
  clearGame: () => void;
  isHost: boolean;
  me: Player | null;
}

const GameContext = createContext<GameContextValue | null>(null);

export function GameProvider({ children }: { children: ReactNode }) {
  const [session, setSessionState] = useState<SessionData | null>(() => getSession());
  const [room, setRoom] = useState<Room | null>(null);
  const [players, setPlayers] = useState<Player[]>([]);
  const [evidence, setEvidence] = useState<Evidence[]>([]);
  const [crime, setCrime] = useState<Crime | null>(null);
  const [interrogationRound, setInterrogationRound] = useState<InterrogationRound | null>(null);
  const [myRole, setMyRole] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const reconnectAttempted = useRef(false);

  const setSession = useCallback((s: SessionData) => {
    saveSession(s);
    setSessionState(s);
  }, []);

  const clearGame = useCallback(() => {
    clearSession();
    setSessionState(null);
    setRoom(null);
    setPlayers([]);
    setEvidence([]);
    setCrime(null);
    setInterrogationRound(null);
    setMyRole(null);
  }, []);

  const refreshRoom = useCallback(async () => {
    if (!session) return;
    try {
      const r = await fetchRoom(session.roomId);
      setRoom(r as Room);
      const p = await fetchPlayers(session.roomId);
      setPlayers(p as Player[]);

      if (['evidence', 'interrogation', 'lie_detector', 'suspect_vote', 'final_vote', 'tie_breaker', 'results'].includes(r.status)) {
        const ev = await fetchEvidence(session.roomId);
        setEvidence(ev as Evidence[]);
      }

      if (r.current_crime_id) {
        const c = await fetchCrime(r.current_crime_id);
        setCrime(c as Crime);
      }

      if (r.status === 'interrogation' && r.current_round > 0) {
        const ir = await fetchInterrogationRound(session.roomId, r.current_round);
        setInterrogationRound(ir as InterrogationRound);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load room');
    }
  }, [session]);

  // Initial load / reconnect
  useEffect(() => {
    async function init() {
      const stored = getSession();
      if (!stored) {
        setLoading(false);
        return;
      }

      if (!reconnectAttempted.current) {
        reconnectAttempted.current = true;
        try {
          await reconnectPlayer(stored.playerId, stored.sessionToken);
        } catch {
          clearSession();
          setSessionState(null);
          setLoading(false);
          return;
        }
      }

      setSessionState(stored);
      try {
        const r = await fetchRoom(stored.roomId);
        setRoom(r as Room);
        const p = await fetchPlayers(stored.roomId);
        setPlayers(p as Player[]);
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to reconnect');
      } finally {
        setLoading(false);
      }
    }
    init();
  }, []);

  // Realtime subscriptions
  useEffect(() => {
    if (!session) return;

    const roomChannel = supabase
      .channel(`room:${session.roomId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'rooms', filter: `id=eq.${session.roomId}` }, (payload) => {
        setRoom(payload.new as Room);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'players', filter: `room_id=eq.${session.roomId}` }, async () => {
        const p = await fetchPlayers(session.roomId);
        setPlayers(p as Player[]);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'evidence', filter: `room_id=eq.${session.roomId}` }, async () => {
        const ev = await fetchEvidence(session.roomId);
        setEvidence(ev as Evidence[]);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'interrogation_rounds', filter: `room_id=eq.${session.roomId}` }, async () => {
        const r = await fetchRoom(session.roomId);
        if (r.current_round > 0) {
          const ir = await fetchInterrogationRound(session.roomId, r.current_round);
          setInterrogationRound(ir as InterrogationRound);
        }
      })
      .subscribe();

    return () => {
      supabase.removeChannel(roomChannel);
    };
  }, [session]);

  // Heartbeat and game tick
  useEffect(() => {
    if (!session) return;

    const interval = setInterval(async () => {
      try {
        await heartbeat(session.playerId, session.sessionToken);
        await gameTick(session.playerId, session.sessionToken);
      } catch {
        // silent
      }
    }, 3000);

    return () => clearInterval(interval);
  }, [session]);

  // Fetch crime when room updates
  useEffect(() => {
    if (!session || !room?.current_crime_id) return;
    fetchCrime(room.current_crime_id).then((c) => setCrime(c as Crime)).catch(() => {});
  }, [session, room?.current_crime_id]);

  // Refresh evidence on phase change
  useEffect(() => {
    if (!session || !room) return;
    if (['evidence', 'interrogation', 'lie_detector', 'results'].includes(room.status)) {
      fetchEvidence(session.roomId).then((ev) => setEvidence(ev as Evidence[])).catch(() => {});
    }
  }, [session, room?.status]);

  const me = players.find((p) => p.id === session?.playerId) ?? null;
  const isHost = me?.is_host ?? false;

  return (
    <GameContext.Provider
      value={{
        session,
        room,
        players,
        evidence,
        crime,
        interrogationRound,
        myRole,
        loading,
        error,
        setSession,
        setMyRole,
        refreshRoom,
        clearGame,
        isHost,
        me,
      }}
    >
      {children}
    </GameContext.Provider>
  );
}

export function useGame() {
  const ctx = useContext(GameContext);
  if (!ctx) throw new Error('useGame must be used within GameProvider');
  return ctx;
}
