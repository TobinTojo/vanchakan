import { useEffect, useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { GameTimer } from '@/components/common/GameTimer';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PlayerList } from '@/components/common/PlayerList';
import { useGame } from '@/context/GameContext';
import { useGameTimer } from '@/hooks/useGameTimer';
import {
  submitLieDetectorVote,
  hasSubmittedLieDetectorVote,
  fetchGameQuestions,
} from '@/services/gameService';
import { formatError } from '@/utils/storage';
import type { LieDetectorAction } from '@/types';

type Step = 'action' | 'evidence' | 'player' | 'question';

export function LieDetectorView() {
  const { session, room, players, evidence } = useGame();
  const [step, setStep] = useState<Step>('action');
  const [action, setAction] = useState<LieDetectorAction | null>(null);
  const [targetId, setTargetId] = useState<string | null>(null);
  const [targetQuestionId, setTargetQuestionId] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [questions, setQuestions] = useState<Array<{ id: string; question_text: string }>>([]);

  const remaining = useGameTimer(room?.phase_ends_at ?? null);

  useEffect(() => {
    if (!session || !room) return;
    hasSubmittedLieDetectorVote(session.roomId, session.playerId, room.lie_detector_event).then(setSubmitted);
    fetchGameQuestions(session.roomId).then((data) => {
      setQuestions(
        data.map((d: { questions: { id: string; question_text: string } }) => d.questions)
      );
    });
  }, [session, room]);

  const handleSubmit = async () => {
    if (!session || !action) return;
    setLoading(true);
    try {
      await submitLieDetectorVote(session.playerId, session.sessionToken, action, {
        evidenceId: action === 'inspect_evidence' ? targetId ?? undefined : undefined,
        playerId: action === 'check_answer' ? targetId ?? undefined : undefined,
        questionId: action === 'check_answer' ? targetQuestionId ?? undefined : undefined,
      });
      setSubmitted(true);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  if (submitted) {
    return (
      <div className="mx-auto max-w-lg animate-fade-in text-center">
        <PhaseHeader phase="Lie Detector" title="Vote Submitted" subtitle="Waiting for results..." />
        <GameTimer remaining={remaining} total={30} />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-xl animate-fade-in">
      <PhaseHeader
        phase="Lie Detector"
        title="Community Vote"
        subtitle="Choose what the group investigates next"
      />

      <div className="mb-6 flex justify-center">
        <GameTimer remaining={remaining} total={30} />
      </div>

      {step === 'action' && (
        <Card>
          <div className="grid gap-3">
            <button
              onClick={() => { setAction('inspect_evidence'); setStep('evidence'); }}
              className="rounded-lg border border-vanchakan-border bg-vanchakan-surface p-4 text-left hover:border-vanchakan-purple transition-all focus:outline-none focus:ring-2 focus:ring-vanchakan-purple"
            >
              <p className="font-semibold text-white">Inspect Evidence</p>
              <p className="text-sm text-vanchakan-muted">Reveal if an evidence card is real or fake</p>
            </button>
            <button
              onClick={() => { setAction('check_answer'); setStep('player'); }}
              className="rounded-lg border border-vanchakan-border bg-vanchakan-surface p-4 text-left hover:border-vanchakan-purple transition-all focus:outline-none focus:ring-2 focus:ring-vanchakan-purple"
            >
              <p className="font-semibold text-white">Check a Player's Answer</p>
              <p className="text-sm text-vanchakan-muted">Reveal someone's real survey answer</p>
            </button>
          </div>
        </Card>
      )}

      {step === 'evidence' && (
        <Card>
          <p className="mb-4 font-semibold text-white">Which evidence should be inspected?</p>
          <div className="grid gap-2 max-h-72 overflow-y-auto">
            {evidence.filter((e) => !e.is_inspected).map((ev) => (
              <button
                key={ev.id}
                onClick={() => setTargetId(ev.id)}
                className={`rounded-lg border p-3 text-left text-sm focus:outline-none focus:ring-2 focus:ring-vanchakan-purple ${
                  targetId === ev.id ? 'border-vanchakan-purple bg-vanchakan-purple/20' : 'border-vanchakan-border'
                }`}
              >
                #{ev.evidence_order}: {ev.evidence_text.slice(0, 80)}{ev.evidence_text.length > 80 ? '...' : ''}
              </button>
            ))}
          </div>
          <div className="mt-4 flex gap-2">
            <Button variant="ghost" onClick={() => setStep('action')}>Back</Button>
            <Button onClick={handleSubmit} disabled={!targetId} loading={loading} className="flex-1">
              Submit Vote
            </Button>
          </div>
        </Card>
      )}

      {step === 'player' && (
        <Card>
          <p className="mb-4 font-semibold text-white">Which player?</p>
          <PlayerList
            players={players}
            currentPlayerId={session?.playerId}
            selectable
            selectedIds={targetId ? [targetId] : []}
            onSelect={setTargetId}
            maxSelections={1}
          />
          <div className="mt-4 flex gap-2">
            <Button variant="ghost" onClick={() => setStep('action')}>Back</Button>
            <Button onClick={() => setStep('question')} disabled={!targetId} className="flex-1">
              Next: Choose Question
            </Button>
          </div>
        </Card>
      )}

      {step === 'question' && (
        <Card>
          <p className="mb-4 font-semibold text-white">Which question?</p>
          <div className="grid gap-2 max-h-60 overflow-y-auto">
            {questions.map((q) => (
              <button
                key={q.id}
                onClick={() => setTargetQuestionId(q.id)}
                className={`rounded-lg border p-3 text-left text-sm focus:outline-none focus:ring-2 focus:ring-vanchakan-purple ${
                  targetQuestionId === q.id ? 'border-vanchakan-purple bg-vanchakan-purple/20' : 'border-vanchakan-border'
                }`}
              >
                {q.question_text}
              </button>
            ))}
          </div>
          <div className="mt-4 flex gap-2">
            <Button variant="ghost" onClick={() => setStep('player')}>Back</Button>
            <Button onClick={handleSubmit} disabled={!targetQuestionId} loading={loading} className="flex-1">
              Submit Vote
            </Button>
          </div>
        </Card>
      )}

      {error && <p className="mt-4 text-sm text-vanchakan-red">{error}</p>}
    </div>
  );
}
