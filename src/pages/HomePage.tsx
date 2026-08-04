import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { Input } from '@/components/common/Input';
import { SoundToggle } from '@/components/common/SoundToggle';
import { ErrorBanner } from '@/components/common/ErrorBanner';
import { createRoom, joinRoom } from '@/services/gameService';
import { useGame } from '@/context/GameContext';
import { formatError } from '@/utils/storage';

export function HomePage() {
  const navigate = useNavigate();
  const { setSession } = useGame();
  const [searchParams] = useSearchParams();
  const [name, setName] = useState('');
  const [roomCode, setRoomCode] = useState(searchParams.get('code')?.toUpperCase() ?? '');

  useEffect(() => {
    const code = searchParams.get('code');
    if (code) setRoomCode(code.toUpperCase());
  }, [searchParams]);
  const [loading, setLoading] = useState<'create' | 'join' | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showHowToPlay, setShowHowToPlay] = useState(false);

  const handleCreate = async () => {
    if (!name.trim()) { setError('Please enter your name'); return; }
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
    if (!name.trim()) { setError('Please enter your name'); return; }
    if (!roomCode.trim()) { setError('Please enter a room code'); return; }
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
    <div className="min-h-screen bg-vanchakan-bg">
      <div className="absolute top-4 right-4">
        <SoundToggle />
      </div>

      <div className="mx-auto max-w-lg px-4 py-12">
        <header className="mb-10 text-center">
          <div className="mb-4 text-6xl">🎭</div>
          <h1 className="font-display text-5xl font-bold text-white">Vanchakan</h1>
          <p className="mt-2 text-vanchakan-muted">
            The social deduction game where someone is lying — and the evidence might be too.
          </p>
        </header>

        {error && <ErrorBanner message={error} onDismiss={() => setError(null)} />}

        <Card className="mb-6" glow>
          <Input
            label="Your Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Enter display name"
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
        </Card>

        <Card>
          <h2 className="mb-4 text-lg font-semibold text-white">Join Room</h2>
          <Input
            label="Room Code"
            value={roomCode}
            onChange={(e) => setRoomCode(e.target.value.toUpperCase())}
            placeholder="ABC123"
            maxLength={6}
            className="mb-4 font-mono tracking-widest uppercase"
          />
          <Button
            onClick={handleJoin}
            loading={loading === 'join'}
            variant="secondary"
            size="lg"
            className="w-full"
          >
            Join Room
          </Button>
        </Card>

        <div className="mt-6 text-center">
          <button
            onClick={() => setShowHowToPlay(!showHowToPlay)}
            className="text-sm text-vanchakan-purple-light underline hover:text-white"
          >
            How to Play
          </button>
        </div>

        {showHowToPlay && (
          <Card className="mt-4 animate-slide-up">
            <ol className="list-decimal space-y-2 pl-5 text-sm text-vanchakan-muted">
              <li>3–8 players join a private room with a code</li>
              <li>Everyone answers 8 survey questions — answers become evidence</li>
              <li>One player is secretly the Vanchakan (criminal)</li>
              <li>One innocent plants fake evidence to confuse everyone</li>
              <li>Interrogate suspects, use the lie detector, and vote</li>
              <li>Catch the Vanchakan before they escape!</li>
            </ol>
          </Card>
        )}
      </div>
    </div>
  );
}
