import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PhaseProgressBar } from '@/components/common/PhaseProgressBar';
import { WaitingScreen } from '@/components/common/WaitingScreen';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';

/** Shown briefly if a room is still in fake_evidence status (legacy/recovery). */
export function FakeEvidenceView() {
  const { remaining, progress } = useSyncedGameTimer(5, true);

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader
        phase="Evidence Lab"
        title="Compiling Evidence"
        subtitle="The game is building the evidence board, including one fake clue..."
      />
      <WaitingScreen message="Analyzing survey answers..." />
      <PhaseProgressBar
        progress={progress}
        label={remaining > 0 ? `Almost ready... ${remaining}s` : 'Opening evidence board...'}
      />
    </div>
  );
}
