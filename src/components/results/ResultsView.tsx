import { useEffect, useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { cleanQuestionText } from '@/components/evidence/EvidenceCard';
import { ART } from '@/assets/art';
import { useGame } from '@/context/GameContext';
import { getGameResults, playAgain, leaveRoom } from '@/services/gameService';
import { sounds } from '@/utils/sounds';
import type { GameResultsData } from '@/types';
import { cn } from '@/utils/storage';

export function ResultsView() {
  const { session, players, isHost, clearGame } = useGame();
  const [results, setResults] = useState<GameResultsData | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!session) return;
    getGameResults(session.playerId, session.sessionToken).then((r) => {
      setResults(r);
      sounds.criminalReveal();
    });
  }, [session]);

  if (!results) {
    return (
      <div className="text-center py-12">
        <p className="text-vanchakan-muted">Revealing results...</p>
      </div>
    );
  }

  const criminalName = results.criminal_name ?? players.find((p) => p.id === results.criminal_id)?.display_name ?? 'Unknown';
  const accusedName = results.accused_name ?? players.find((p) => p.id === results.accused_id)?.display_name ?? 'Unknown';
  const jesterName = results.jester_name ?? players.find((p) => p.id === results.jester_id)?.display_name;
  const fakeWriterName = results.fake_writer_name ?? players.find((p) => p.id === results.fake_writer_id)?.display_name;

  const jesterWins = results.winning_side === 'jester';
  const detectivesWin = results.winning_side === 'detectives';

  const headerTitle = jesterWins
    ? 'The Jester wins alone!'
    : detectivesWin
      ? 'The Vanchakan has been caught!'
      : 'The Vanchakan escaped!';

  const resultImage = jesterWins ? ART.roleJester : detectivesWin ? ART.win : ART.loss;

  const handlePlayAgain = async () => {
    if (!session) return;
    setLoading(true);
    try {
      await playAgain(session.playerId, session.sessionToken);
    } finally {
      setLoading(false);
    }
  };

  const handleLeave = async () => {
    if (session) {
      try {
        await leaveRoom(session.playerId, session.sessionToken);
      } catch {
        /* ignore */
      }
    }
    clearGame();
    window.location.href = '/';
  };

  return (
    <div className="mx-auto max-w-2xl animate-fade-in">
      <PhaseHeader phase="Final Reveal" title={headerTitle} />

      <Card glow className="mb-6 text-center animate-reveal">
        <div className="mb-4 flex justify-center">
          <img
            src={resultImage}
            alt=""
            className="h-32 w-32 rounded-2xl object-cover ring-2 ring-white/10 sm:h-36 sm:w-36"
          />
        </div>
        <div className="space-y-3">
          {jesterWins ? (
            <>
              <p className="text-lg text-white">
                The group voted to accuse{' '}
                <strong className="text-vanchakan-purple-light">{accusedName}</strong>
              </p>
              <p className="text-xl text-white">
                They were the <strong className="text-vanchakan-purple-light">Jester</strong>
              </p>
              <p className="text-vanchakan-muted">
                The Jester wanted to be caught — only they win. Detectives and Vanchakan both lose.
              </p>
            </>
          ) : (
            <>
              <p className="text-lg text-white">
                The group voted to accuse{' '}
                <strong className="text-vanchakan-gold">{accusedName}</strong>
              </p>
              <p className="text-xl text-white">
                The real Vanchakan was{' '}
                <strong className="text-vanchakan-red">{criminalName}</strong>
              </p>
              <p className="text-vanchakan-muted">
                {detectivesWin
                  ? 'The detectives caught the Vanchakan — you win!'
                  : 'The Vanchakan escaped justice — the criminal wins!'}
              </p>
            </>
          )}
        </div>
      </Card>

      {jesterName && (
        <Card className="mb-6 text-center">
          <p className="text-sm text-vanchakan-muted">
            The Jester was{' '}
            <strong className="text-vanchakan-purple-light">{jesterName}</strong>
            {jesterWins ? ' — mission accomplished.' : '.'}
          </p>
        </Card>
      )}

      <Card className="mb-6">
        <h3 className="font-semibold text-vanchakan-gold mb-4">Evidence Summary</h3>
        <div className="space-y-2">
          {results.evidence.map((ev) => {
            const hasStructured = Boolean(ev.question_text?.trim()) && Boolean(ev.answer_text?.trim());
            return (
              <div
                key={ev.order}
                className={cn(
                  'rounded-lg border p-3 text-sm',
                  ev.is_fake ? 'border-vanchakan-red/50 bg-vanchakan-red/5' : 'border-green-500/30 bg-green-500/5'
                )}
              >
                <div className="flex items-center justify-between mb-1">
                  <span className="text-xs font-bold text-vanchakan-gold">#{ev.order}</span>
                  <span
                    className={cn(
                      'text-xs font-semibold',
                      ev.is_fake ? 'text-vanchakan-red' : 'text-green-400'
                    )}
                  >
                    {ev.is_fake ? 'FAKE' : 'REAL'}
                    {ev.is_inspected && ` — ${ev.inspection_result}`}
                  </span>
                </div>
                {hasStructured ? (
                  <div className="space-y-1">
                    <p className="text-white/80">{cleanQuestionText(ev.question_text!)}</p>
                    <p className="font-semibold text-vanchakan-gold">"{ev.answer_text}"</p>
                  </div>
                ) : (
                  <p className="text-white">{ev.text}</p>
                )}
              </div>
            );
          })}
        </div>
        {fakeWriterName && (
          <p className="mt-4 text-sm text-vanchakan-muted">
            Fake clue source:{' '}
            <strong className="text-white">{fakeWriterName}</strong> — an innocent
            player's survey answer was used as the planted red herring (not the criminal).
          </p>
        )}
      </Card>

      <div className="flex flex-col gap-3 sm:flex-row">
        {isHost && (
          <Button onClick={handlePlayAgain} loading={loading} className="flex-1">
            Play Again
          </Button>
        )}
        <Button variant="secondary" onClick={handleLeave} className="flex-1">
          Leave Room
        </Button>
      </div>
      {!isHost && (
        <p className="mt-4 text-center text-sm text-vanchakan-muted">
          Waiting for the host to start a new game...
        </p>
      )}
    </div>
  );
}
