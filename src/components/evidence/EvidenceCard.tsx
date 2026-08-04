import { cn } from '@/utils/storage';
import type { Evidence } from '@/types';

interface EvidenceCardProps {
  evidence: Evidence;
  active?: boolean;
  showMatchCount?: boolean;
}

/** Strip trailing "You:" from survey question prompts for cleaner display. */
export function cleanQuestionText(text: string): string {
  return text.replace(/\s+You:\s*$/i, '').trim();
}

export function EvidenceCard({ evidence, active, showMatchCount = true }: EvidenceCardProps) {
  const matchCount = evidence.matching_count;
  const totalPlayers = evidence.total_players;
  const showCount =
    showMatchCount &&
    matchCount !== undefined &&
    totalPlayers !== undefined &&
    totalPlayers > 0;

  const hasStructured =
    Boolean(evidence.question_text?.trim()) && Boolean(evidence.answer_text?.trim());

  return (
    <div
      className={cn(
        'rounded-lg border p-4 transition-all animate-slide-up',
        evidence.is_inspected
          ? evidence.inspection_result === 'Fake Evidence'
            ? 'border-vanchakan-red bg-vanchakan-red/10'
            : 'border-green-500/50 bg-green-500/10'
          : 'border-vanchakan-border bg-vanchakan-surface',
        active && 'ring-2 ring-vanchakan-gold'
      )}
    >
      <div className="mb-3 flex items-center justify-between gap-2">
        <span className="text-xs font-bold uppercase tracking-wider text-vanchakan-gold">
          Evidence #{evidence.evidence_order}
        </span>
        <div className="flex items-center gap-2">
          {showCount && (
            <span className="rounded-full bg-vanchakan-purple/20 px-2 py-0.5 text-xs font-semibold text-vanchakan-purple">
              {matchCount} of {totalPlayers} gave this answer
            </span>
          )}
          {evidence.is_inspected && (
            <span
              className={cn(
                'rounded-full px-2 py-0.5 text-xs font-semibold',
                evidence.inspection_result === 'Fake Evidence'
                  ? 'bg-vanchakan-red/20 text-vanchakan-red'
                  : 'bg-green-500/20 text-green-400'
              )}
            >
              {evidence.inspection_result}
            </span>
          )}
        </div>
      </div>

      {hasStructured ? (
        <div className="space-y-2">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-vanchakan-muted">
              Survey question
            </p>
            <p className="text-sm text-white/90">{cleanQuestionText(evidence.question_text!)}</p>
          </div>
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-vanchakan-muted">
              Criminal's answer
            </p>
            <p className="text-base font-semibold text-vanchakan-gold">"{evidence.answer_text}"</p>
          </div>
        </div>
      ) : (
        <p className="text-sm text-white">{evidence.evidence_text}</p>
      )}
    </div>
  );
}
