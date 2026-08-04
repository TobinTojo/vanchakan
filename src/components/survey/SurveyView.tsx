import { useEffect, useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { WaitingScreen } from '@/components/common/WaitingScreen';
import { useGame } from '@/context/GameContext';
import {
  fetchCurrentGameQuestion,
  submitAnswer,
  getAnswerCount,
  fetchMyAnswer,
  tryAdvanceSurveyIfReady,
} from '@/services/gameService';
import { formatError } from '@/utils/storage';
import { sounds } from '@/utils/sounds';
import type { Question } from '@/types';

export function SurveyView() {
  const { session, room } = useGame();
  const [question, setQuestion] = useState<Question | null>(null);
  const [selected, setSelected] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [answerCount, setAnswerCount] = useState({ answered: 0, total: 0 });
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!session || !room) return;

    async function load() {
      const { question: q } = await fetchCurrentGameQuestion(
        session!.roomId,
        room!.current_question_index
      );
      setQuestion(q as Question);

      const existing = await fetchMyAnswer(session!.roomId, session!.playerId, q.id);
      if (existing) {
        setSubmitted(true);
        setSelected(existing.answer_text);
      } else {
        setSubmitted(false);
        setSelected('');
      }

      const count = await getAnswerCount(session!.roomId);
      setAnswerCount(count);
    }

    load();
  }, [session, room?.current_question_index, room?.phase_ends_at]);

  useEffect(() => {
    if (!session || !room) return;
    const interval = setInterval(async () => {
      const count = await getAnswerCount(session.roomId);
      setAnswerCount(count);
      if (count.answered >= count.total && count.total > 0) {
        await tryAdvanceSurveyIfReady(session.playerId, session.sessionToken);
      }
    }, 1500);
    return () => clearInterval(interval);
  }, [session, room?.current_question_index]);

  const handleSubmit = async () => {
    if (!session || !selected.trim()) return;
    setLoading(true);
    setError(null);
    try {
      await submitAnswer(session.playerId, session.sessionToken, selected);
      setSubmitted(true);
      sounds.submit();
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  if (!question || !room) return <WaitingScreen message="Loading question..." />;

  const isShortAnswer = question.question_type === 'short_answer';

  return (
    <div className="mx-auto max-w-xl animate-fade-in">
      <PhaseHeader
        phase="Survey"
        title={`Question ${room.current_question_index} of 8`}
        subtitle="Answer honestly — your responses may become evidence!"
      />

      <Card glow>
        <p className="mb-6 text-lg text-white">{question.question_text}</p>

        {submitted ? (
          <WaitingScreen message="Answer locked in. Waiting for the other players." />
        ) : isShortAnswer ? (
          <div className="space-y-4">
            <input
              type="text"
              value={selected}
              onChange={(e) => setSelected(e.target.value)}
              placeholder="Type your answer..."
              maxLength={40}
              className="w-full rounded-lg border border-vanchakan-border bg-vanchakan-surface px-4 py-3 text-white focus:border-vanchakan-purple focus:outline-none focus:ring-2 focus:ring-vanchakan-purple/30"
              aria-label="Your answer"
            />
            <p className="text-right text-xs text-vanchakan-muted">{selected.length}/40</p>
            <Button onClick={handleSubmit} disabled={!selected.trim()} loading={loading} className="w-full">
              Submit Answer
            </Button>
          </div>
        ) : (
          <div className="grid gap-3">
            {(question.options as string[])?.map((option) => (
              <button
                key={option}
                onClick={() => setSelected(option)}
                className={`rounded-lg border px-4 py-3 text-left transition-all focus:outline-none focus:ring-2 focus:ring-vanchakan-purple ${
                  selected === option
                    ? 'border-vanchakan-purple bg-vanchakan-purple/20 text-white'
                    : 'border-vanchakan-border bg-vanchakan-surface text-white hover:border-vanchakan-purple/50'
                }`}
                aria-pressed={selected === option}
              >
                {option}
              </button>
            ))}
            <Button onClick={handleSubmit} disabled={!selected} loading={loading} className="mt-2 w-full">
              Submit Answer
            </Button>
          </div>
        )}

        {error && <p className="mt-4 text-sm text-vanchakan-red">{error}</p>}
      </Card>

      <p className="mt-4 text-center text-sm text-vanchakan-muted">
        {answerCount.answered} of {answerCount.total} players answered
      </p>
    </div>
  );
}
