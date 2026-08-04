import { useState } from 'react';
import { Button } from '@/components/common/Button';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { useGame } from '@/context/GameContext';
import { startInterrogation } from '@/services/gameService';
import { EvidenceCard } from '@/components/evidence/EvidenceCard';

export function EvidenceBoardView() {
  const { session, evidence, isHost } = useGame();
  const [loading, setLoading] = useState(false);

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
          <EvidenceCard key={ev.id} evidence={ev} showMatchCount />
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
