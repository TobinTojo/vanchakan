import { useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useGame } from '@/context/GameContext';
import { LobbyView } from '@/components/lobby/LobbyView';
import { SurveyView } from '@/components/survey/SurveyView';
import { RoleRevealView } from '@/components/evidence/RoleRevealView';
import { CrimeRevealView } from '@/components/evidence/CrimeRevealView';
import { FakeEvidenceView } from '@/components/evidence/FakeEvidenceView';
import { EvidenceBoardView } from '@/components/evidence/EvidenceBoardView';
import { InterrogationView } from '@/components/interrogation/InterrogationView';
import { LieDetectorView } from '@/components/interrogation/LieDetectorView';
import { SuspectVoteView } from '@/components/voting/SuspectVoteView';
import { FinalVoteView } from '@/components/voting/FinalVoteView';
import { ResultsView } from '@/components/results/ResultsView';
import { WaitingScreen } from '@/components/common/WaitingScreen';
import { DevPanel } from '@/components/common/DevPanel';
import { SoundToggle } from '@/components/common/SoundToggle';

function GamePhaseRouter() {
  const { room } = useGame();

  if (!room) return <WaitingScreen message="Connecting to room..." />;

  switch (room.status) {
    case 'lobby':
      return <LobbyView />;
    case 'survey':
      return <SurveyView />;
    case 'role_reveal':
      return <RoleRevealView />;
    case 'crime_reveal':
      return <CrimeRevealView />;
    case 'fake_evidence':
      return <FakeEvidenceView />;
    case 'evidence':
      return <EvidenceBoardView />;
    case 'interrogation':
      return <InterrogationView />;
    case 'lie_detector':
      return <LieDetectorView />;
    case 'suspect_vote':
      return <SuspectVoteView />;
    case 'final_vote':
    case 'tie_breaker':
      return <FinalVoteView />;
    case 'results':
    case 'finished':
      return <ResultsView />;
    default:
      return <WaitingScreen message={`Phase: ${room.status}`} />;
  }
}

export function RoomPage() {
  const { code } = useParams<{ code: string }>();
  const navigate = useNavigate();
  const { session, loading } = useGame();

  useEffect(() => {
    if (!loading && !session) {
      navigate('/', { replace: true });
    }
  }, [loading, session, navigate]);

  useEffect(() => {
    if (session && code && session.roomCode !== code.toUpperCase()) {
      // URL code mismatch is fine if session exists
    }
  }, [session, code]);

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-vanchakan-bg">
        <WaitingScreen message="Reconnecting..." />
      </div>
    );
  }

  if (!session) return null;

  return (
    <div className="min-h-screen bg-vanchakan-bg px-4 py-8">
      <div className="absolute top-4 right-4">
        <SoundToggle />
      </div>
      <GamePhaseRouter />
      <DevPanel />
    </div>
  );
}
