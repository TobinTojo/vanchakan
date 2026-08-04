import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { Input } from '@/components/common/Input';
import { ErrorBanner } from '@/components/common/ErrorBanner';
import { SiteLayout } from '@/components/layout/SiteLayout';
import { createRoom, joinRoom } from '@/services/gameService';
import { useGame } from '@/context/GameContext';
import { formatError } from '@/utils/storage';

const FEATURES = [
  { icon: '👥', label: '3–8 players' },
  { icon: '🔍', label: 'Survey & evidence' },
  { icon: '🎭', label: 'Hidden roles' },
  { icon: '📱', label: 'Play on any device' },
];

export function HomePage() {
  const navigate = useNavigate();
  const { setSession } = useGame();
  const [searchParams] = useSearchParams();
  const [name, setName] = useState('');
  const [roomCode, setRoomCode] = useState(searchParams.get('code')?.toUpperCase() ?? '');
  const [loading, setLoading] = useState<'create' | 'join' | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showHowToPlay, setShowHowToPlay] = useState(false);

  useEffect(() => {
    const code = searchParams.get('code');
    if (code) setRoomCode(code.toUpperCase());
  }, [searchParams]);

  const handleCreate = async () => {
    if (!name.trim()) {
      setError('Please enter your name');
      return;
    }
    setLoading('create');
    setError(null);
    try {
      const result = await createRoom(name);
      setSession({
        playerId: result.player_id,
        roomId: result.room_id,
        sessionToken: result.sessionToken,
        displayName: name.trim(),
        roomCode: result.room_code,
      });
      navigate(`/room/${result.room_code}`);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(null);
    }
  };

  const handleJoin = async () => {
    if (!name.trim()) {
      setError('Please enter your name');
      return;
    }
    if (!roomCode.trim()) {
      setError('Please enter a room code');
      return;
    }
    setLoading('join');
    setError(null);
    try {
      const result = await joinRoom(roomCode, name);
      setSession({
        playerId: result.player_id,
        roomId: result.room_id,
        sessionToken: result.sessionToken,
        displayName: name.trim(),
        roomCode: result.room_code,
      });
      navigate(`/room/${result.room_code}`);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(null);
    }
  };

  return (
    <SiteLayout onHowToPlay={() => setShowHowToPlay(true)}>
      {/* Hero */}
      <section className="page-container pb-8 pt-4 sm:pt-10">
        <div className="grid items-center gap-10 lg:grid-cols-2 lg:gap-16">
          <div className="text-center lg:text-left">
            <p className="mb-3 inline-block rounded-full border border-vanchakan-purple/30 bg-vanchakan-purple/10 px-3 py-1 text-xs font-semibold uppercase tracking-wider text-vanchakan-purple-light">
              Multiplayer social deduction
            </p>
            <h1 className="font-display text-4xl font-bold leading-tight text-white sm:text-5xl lg:text-6xl">
              Catch the{' '}
              <span className="bg-gradient-to-r from-vanchakan-gold to-vanchakan-purple-light bg-clip-text text-transparent">
                Vanchakan
              </span>
            </h1>
            <p className="mt-4 max-w-lg text-base leading-relaxed text-vanchakan-muted sm:text-lg lg:mx-0 mx-auto">
              Answer survey questions, study the evidence, interrogate suspects, and vote — but
              someone is lying, and one clue is fake.
            </p>

            <div className="mt-6 flex flex-wrap justify-center gap-2 lg:justify-start">
              {FEATURES.map((f) => (
                <span
                  key={f.label}
                  className="inline-flex items-center gap-1.5 rounded-full border border-vanchakan-border bg-vanchakan-surface/80 px-3 py-1.5 text-xs font-medium text-vanchakan-muted"
                >
                  <span>{f.icon}</span>
                  {f.label}
                </span>
              ))}
            </div>

            <button
              type="button"
              onClick={() => setShowHowToPlay(true)}
              className="mt-4 text-sm font-medium text-vanchakan-purple-light underline-offset-2 hover:underline sm:hidden"
            >
              How to Play
            </button>
          </div>

          {/* Join form */}
          <div className="w-full max-w-md mx-auto lg:max-w-none lg:ml-auto">
            {error && (
              <div className="mb-4">
                <ErrorBanner message={error} onDismiss={() => setError(null)} />
              </div>
            )}

            <Card glow className="shadow-glow">
              <h2 className="mb-1 text-lg font-semibold text-white">Get started</h2>
              <p className="mb-5 text-sm text-vanchakan-muted">No account needed — just a name.</p>

              <Input
                label="Your Name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Display name"
                maxLength={20}
                autoComplete="off"
              />

              <Button
                onClick={handleCreate}
                loading={loading === 'create'}
                size="lg"
                className="mt-4 w-full"
              >
                Create Room
              </Button>

              <div className="my-5 flex items-center gap-3">
                <div className="h-px flex-1 bg-vanchakan-border" />
                <span className="text-xs font-medium uppercase tracking-wider text-vanchakan-muted">
                  or join
                </span>
                <div className="h-px flex-1 bg-vanchakan-border" />
              </div>

              <Input
                label="Room Code"
                value={roomCode}
                onChange={(e) => setRoomCode(e.target.value.toUpperCase())}
                placeholder="ABC123"
                maxLength={6}
                className="font-mono tracking-widest uppercase"
              />
              <Button
                onClick={handleJoin}
                loading={loading === 'join'}
                variant="secondary"
                size="lg"
                className="mt-4 w-full"
              >
                Join Room
              </Button>
            </Card>
          </div>
        </div>
      </section>

      {showHowToPlay && (
        <section className="page-container pb-12 animate-slide-up">
          <Card>
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold text-white">How to Play</h2>
              <button
                type="button"
                onClick={() => setShowHowToPlay(false)}
                className="text-vanchakan-muted hover:text-white"
                aria-label="Close"
              >
                ✕
              </button>
            </div>
            <ol className="list-decimal space-y-3 pl-5 text-sm leading-relaxed text-vanchakan-muted">
              <li>3–8 players join a private room with a 6-character code</li>
              <li>Everyone answers 8 survey questions — answers become evidence</li>
              <li>One player is secretly the Vanchakan (criminal)</li>
              <li>Study evidence, interrogate suspects, and use the lie detector</li>
              <li>Vote on your top suspects and make a final accusation</li>
              <li>Catch the Vanchakan before they escape!</li>
            </ol>
          </Card>
        </section>
      )}
    </SiteLayout>
  );
}
