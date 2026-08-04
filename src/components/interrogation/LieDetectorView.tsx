import { useEffect, useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { GameTimer } from '@/components/common/GameTimer';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { WaitingScreen } from '@/components/common/WaitingScreen';
import { EvidenceCard, cleanQuestionText } from '@/components/evidence/EvidenceCard';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import {
  submitLieDetectorVote,
  hasSubmittedLieDetectorVote,
  getLieDetectorState,
} from '@/services/gameService';
import { formatError, cn } from '@/utils/storage';
import type { Evidence, LieDetectorState, LieDetectorStep } from '@/types';

function stepVotePhase(step: LieDetectorStep): 'evidence' | 'player' | null {
  if (step === 'vote_evidence') return 'evidence';
  if (step === 'vote_player') return 'player';
  return null;
}

export function LieDetectorView() {
  const { session, room, players } = useGame();
  const [state, setState] = useState<LieDetectorState | null>(null);
  const [selectedEvidenceId, setSelectedEvidenceId] = useState<string | null>(null);
  const [submittedEvidence, setSubmittedEvidence] = useState(false);
  const [submittedPlayer, setSubmittedPlayer] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const step = room?.lie_detector_step ?? state?.step ?? 'vote_evidence';
  const isReveal = step === 'reveal_evidence' || step === 'reveal_player';
  const { remaining } = useSyncedGameTimer(isReveal ? 12 : 0, false, !isReveal);

  useEffect(() => {
    if (!session || !room) return;

    const load = async () => {
      const next = await getLieDetectorState(session.roomId);
      setState(next);
      if (next) {
        const [evidenceVote, playerVote] = await Promise.all([
          hasSubmittedLieDetectorVote(session.roomId, session.playerId, next.event_number, 'evidence'),
          hasSubmittedLieDetectorVote(session.roomId, session.playerId, next.event_number, 'player'),
        ]);
        setSubmittedEvidence(evidenceVote);
        setSubmittedPlayer(playerVote);
      }
    };

    load();
    const interval = setInterval(load, 2000);
    return () => clearInterval(interval);
  }, [session, room?.lie_detector_step, room?.lie_detector_event, room?.phase_ends_at]);

  const handleEvidenceVote = async () => {
    if (!session || !selectedEvidenceId) return;
    setLoading(true);
    setError(null);
    try {
      await submitLieDetectorVote(session.playerId, session.sessionToken, 'inspect_evidence', {
        evidenceId: selectedEvidenceId,
      });
      setSubmittedEvidence(true);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  const handlePlayerVote = async () => {
    if (!session || !state?.attached_player) return;
    setLoading(true);
    setError(null);
    try {
      await submitLieDetectorVote(session.playerId, session.sessionToken, 'check_answer', {
        playerId: state.attached_player.id,
        questionId: state.attached_player.question_id,
      });
      setSubmittedPlayer(true);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

  if (!room || !state) {
    return <WaitingScreen message="Loading lie detector..." />;
  }

  const eventLabel = state.event_number === 1 ? 'after Round 3' : 'after Round 6';
  const votePhase = stepVotePhase(step);

  if (step === 'reveal_evidence' && state.evidence_result) {
    const inspected = state.evidence_options.find(
      (e) => e.id === state.evidence_result?.target_evidence_id
    );

    return (
      <div className="mx-auto max-w-lg animate-fade-in">
        <PhaseHeader
          phase="Lie Detector"
          title="Evidence Revealed"
          subtitle={`Group choice ${eventLabel}`}
        />
        {inspected && (
          <div className="mb-6">
            <EvidenceCard evidence={inspected} showMatchCount />
          </div>
        )}
        <Card glow className="mb-6 text-center">
          <p className="text-xs font-semibold uppercase text-vanchakan-gold">Inspection Result</p>
          <p className="mt-2 text-2xl font-bold text-white">
            Evidence #{state.evidence_result.evidence_order}: {state.evidence_result.inspection_result}
          </p>
        </Card>
        <GameTimer remaining={remaining} total={12} label="Checking player answer in" />
      </div>
    );
  }

  if (step === 'reveal_player' && state.player_result) {
    const result = state.player_result;

    return (
      <div className="mx-auto max-w-lg animate-fade-in">
        <PhaseHeader phase="Lie Detector" title="Answer Revealed" subtitle="The group has spoken" />
        <Card glow className="mb-6">
          <div className="space-y-2">
            <p className="text-xs font-semibold uppercase text-vanchakan-gold">Player Answer</p>
            <p className="text-white">
              <strong>{result.player_name}</strong> answered:
            </p>
            <p className="text-sm text-vanchakan-muted">
              {result.question_text ? cleanQuestionText(result.question_text) : 'Survey question'}
            </p>
            <p className="text-lg font-semibold text-vanchakan-gold">"{result.answer_text}"</p>
            {result.answer_verdict && (
              <div className="pt-2">
                <span
                  className={cn(
                    'inline-flex rounded-full border px-4 py-1.5 text-sm font-semibold text-white',
                    result.answer_verdict === 'dishonest'
                      ? 'border-red-500/60 bg-red-500/20'
                      : 'border-green-500/60 bg-green-500/20'
                  )}
                >
                  {result.answer_verdict === 'dishonest' ? 'Dishonest' : 'Honest'}
                </span>
                <p className="mt-2 text-xs text-vanchakan-muted">
                  {result.answer_verdict === 'dishonest'
                    ? "Matches the criminal's answer — suspicious."
                    : "Does not match the criminal's answer."}
                </p>
              </div>
            )}
          </div>
        </Card>
        <GameTimer remaining={remaining} total={12} label="Continuing in" />
      </div>
    );
  }

  if (votePhase === 'evidence' && submittedEvidence) {
    return (
      <div className="mx-auto max-w-lg animate-fade-in text-center">
        <PhaseHeader
          phase="Lie Detector"
          title="Vote Submitted"
          subtitle="Waiting for everyone to pick an evidence card..."
        />
        <WaitingScreen message="The group is choosing which interrogated evidence to inspect." />
      </div>
    );
  }

  if (votePhase === 'player' && submittedPlayer) {
    return (
      <div className="mx-auto max-w-lg animate-fade-in text-center">
        <PhaseHeader
          phase="Lie Detector"
          title="Vote Submitted"
          subtitle="Waiting to check the attached player's answer..."
        />
        <WaitingScreen message="Almost there — revealing the answer next." />
      </div>
    );
  }

  if (votePhase === 'evidence') {
    const options = state.evidence_options as Evidence[];

    return (
      <div className="mx-auto max-w-xl animate-fade-in">
        <PhaseHeader
          phase="Lie Detector"
          title="Vote: Inspect Evidence"
          subtitle={`Choose one evidence card interrogated in rounds 1–${state.event_number === 1 ? 3 : 6}`}
        />

        <Card>
          <p className="mb-4 text-sm text-vanchakan-muted">
            Everyone votes on which interrogated evidence to inspect. The majority choice will be
            revealed as genuine or fake.
          </p>
          <div className="grid gap-3 max-h-[28rem] overflow-y-auto">
            {options.length === 0 ? (
              <p className="text-center text-vanchakan-muted">No interrogated evidence available.</p>
            ) : (
              options.map((ev) => (
                <button
                  key={ev.id}
                  type="button"
                  onClick={() => setSelectedEvidenceId(ev.id)}
                  className={cn(
                    'rounded-lg text-left transition-all focus:outline-none focus:ring-2 focus:ring-vanchakan-purple',
                    selectedEvidenceId === ev.id && 'ring-2 ring-vanchakan-gold'
                  )}
                >
                  <EvidenceCard evidence={ev} active={selectedEvidenceId === ev.id} showMatchCount />
                </button>
              ))
            )}
          </div>
          <Button
            onClick={handleEvidenceVote}
            disabled={!selectedEvidenceId || options.length === 0}
            loading={loading}
            className="mt-4 w-full"
          >
            Submit Vote
          </Button>
        </Card>

        {error && <p className="mt-4 text-sm text-vanchakan-red">{error}</p>}
      </div>
    );
  }

  if (votePhase === 'player' && state.attached_player) {
    const attached = players.find((p) => p.id === state.attached_player?.id);

    return (
      <div className="mx-auto max-w-xl animate-fade-in">
        <PhaseHeader
          phase="Lie Detector"
          title="Vote: Check Player Answer"
          subtitle="Confirm checking the player attached to the chosen evidence"
        />

        {state.evidence_result && (
          <div className="mb-6">
            <Card className="text-center">
              <p className="text-xs font-semibold uppercase text-vanchakan-gold">Selected Evidence</p>
              <p className="mt-1 text-lg font-semibold text-white">
                Evidence #{state.evidence_result.evidence_order}:{' '}
                {state.evidence_result.inspection_result}
              </p>
            </Card>
          </div>
        )}

        <Card>
          <p className="mb-4 text-sm text-vanchakan-muted">
            The player attached to this evidence card is{' '}
            <strong className="text-white">{attached?.display_name ?? state.attached_player.name}</strong>.
            Everyone must vote to reveal their survey answer for this question.
          </p>
          {state.attached_player.question_text && (
            <p className="mb-4 rounded-lg border border-vanchakan-border bg-vanchakan-surface p-3 text-sm text-white/90">
              {cleanQuestionText(state.attached_player.question_text)}
            </p>
          )}
          <Button onClick={handlePlayerVote} loading={loading} className="w-full">
            Vote to Reveal {attached?.display_name ?? state.attached_player.name}'s Answer
          </Button>
        </Card>

        {error && <p className="mt-4 text-sm text-vanchakan-red">{error}</p>}
      </div>
    );
  }

  return <WaitingScreen message="Loading lie detector phase..." />;
}
