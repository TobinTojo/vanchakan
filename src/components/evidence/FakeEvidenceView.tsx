import { useEffect, useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { GameTimer } from '@/components/common/GameTimer';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PhaseProgressBar } from '@/components/common/PhaseProgressBar';
import { WaitingScreen } from '@/components/common/WaitingScreen';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { getFakeEvidenceTask, submitFakeEvidence } from '@/services/gameService';
import { formatError } from '@/utils/storage';
import type { FakeEvidenceTask } from '@/types';

export function FakeEvidenceView() {
  const { session, room } = useGame();
  const [task, setTask] = useState<FakeEvidenceTask | null>(null);
  const [answer, setAnswer] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [checked, setChecked] = useState(false);

  const { remaining, progress } = useSyncedGameTimer(30, true);

  useEffect(() => {
    if (!session) return;
    getFakeEvidenceTask(session.playerId, session.sessionToken).then((t) => {
      setTask(t);
      setChecked(true);
    });
  }, [session]);

  const handleSubmit = async () => {
    if (!session || !answer.trim()) return;
    setLoading(true);
    setError(null);
    try {
      await submitFakeEvidence(session.playerId, session.sessionToken, answer);
      setSubmitted(true);
    } catch (e) {
      // Phase may have advanced via another client or timer
      if (room?.status === 'evidence' || room?.status === 'interrogation') {
        setSubmitted(true);
        return;
      }
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  if (!checked) return <WaitingScreen message="Checking assignment..." />;

  if (!task) {
    return (
      <div className="mx-auto max-w-lg animate-fade-in">
        <PhaseHeader phase="Red Herring" title="Stand By" subtitle="Another player is planting false evidence..." />
        <WaitingScreen message="Waiting for the fake evidence to be planted..." />
        <PhaseProgressBar
          progress={progress}
          label={remaining > 0 ? `Auto-generating in ${remaining}s if needed...` : 'Building evidence board...'}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-xl animate-fade-in">
      <PhaseHeader
        phase="Secret Mission"
        title="Plant Fake Evidence"
        subtitle="Write a believable answer to confuse the detectives. Nobody will know you wrote it."
      />

      <div className="mb-6 flex justify-center">
        <GameTimer remaining={remaining} total={30} />
      </div>

      <Card glow>
        <p className="mb-4 text-lg text-white">{task.question_text}</p>

        {submitted ? (
          <WaitingScreen message="Fake evidence planted. Waiting for others..." />
        ) : task.question_type === 'multiple_choice' && task.options ? (
          <div className="grid gap-3">
            {task.options.map((opt) => (
              <button
                key={opt}
                onClick={() => setAnswer(opt)}
                className={`rounded-lg border px-4 py-3 text-left transition-all ${
                  answer === opt
                    ? 'border-vanchakan-red bg-vanchakan-red/20 text-white'
                    : 'border-vanchakan-border bg-vanchakan-surface text-white hover:border-vanchakan-red/50'
                }`}
              >
                {opt}
              </button>
            ))}
            <Button onClick={handleSubmit} disabled={!answer} loading={loading} className="w-full">
              Plant Evidence
            </Button>
          </div>
        ) : (
          <div className="space-y-4">
            <input
              type="text"
              value={answer}
              onChange={(e) => setAnswer(e.target.value)}
              placeholder="Write a convincing fake answer..."
              maxLength={200}
              className="w-full rounded-lg border border-vanchakan-border bg-vanchakan-surface px-4 py-3 text-white focus:border-vanchakan-red focus:outline-none"
            />
            <Button onClick={handleSubmit} disabled={!answer.trim()} loading={loading} variant="danger" className="w-full">
              Plant Evidence
            </Button>
          </div>
        )}
        {error && <p className="mt-4 text-sm text-vanchakan-red">{error}</p>}
      </Card>
    </div>
  );
}
