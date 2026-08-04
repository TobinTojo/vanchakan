import { useState } from 'react';
import { Button } from '@/components/common/Button';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { useGame } from '@/context/GameContext';
import { startInterrogation } from '@/services/gameService';
import { cn } from '@/utils/storage';
import type { Evidence } from '@/types';

function EvidenceCard({ evidence, active }: { evidence: Evidence; active?: boolean }) {
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
      <div className="mb-2 flex items-center justify-between">
        <span className="text-xs font-bold uppercase tracking-wider text-vanchakan-gold">
          Evidence #{evidence.evidence_order}
        </span>
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
      <p className="text-sm text-white">{evidence.evidence_text}</p>
    </div>
  );
}

export function EvidenceBoardView() {
  const { session, evidence, isHost } = useGame();
  const [loading, setLoading] = useState(false);
  const [activeId, setActiveId] = useState<string | null>(null);

  const handleStartInterrogation = async () => {
    if (!session) return;
    setLoading(true);
    try {
      await startInterrogation(session.playerId, session.sessionToken);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-2xl animate-fade-in">
      <PhaseHeader
        phase="Evidence Board"
        title="The Evidence"
        subtitle="Study each clue carefully. One piece of evidence is a lie."
      />

      <div className="grid gap-3 sm:grid-cols-2">
        {evidence.map((ev) => (
          <button
            key={ev.id}
            onClick={() => setActiveId(ev.id === activeId ? null : ev.id)}
            className="text-left focus:outline-none focus:ring-2 focus:ring-vanchakan-purple rounded-lg"
          >
            <EvidenceCard evidence={ev} active={ev.id === activeId} />
          </button>
        ))}
      </div>

      {isHost && (
        <div className="mt-8 text-center">
          <Button onClick={handleStartInterrogation} loading={loading} size="lg">
            Begin Interrogation
          </Button>
        </div>
      )}

      {!isHost && (
        <p className="mt-6 text-center text-vanchakan-muted">Waiting for host to begin interrogation...</p>
      )}
    </div>
  );
}
