import { useEffect } from 'react';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { useGame } from '@/context/GameContext';
import { getMyRole } from '@/services/gameService';
import { sounds } from '@/utils/sounds';

export function RoleRevealView() {
  const { session, myRole, setMyRole } = useGame();

  useEffect(() => {
    if (!session || myRole) return;
    getMyRole(session.playerId, session.sessionToken).then((role) => {
      setMyRole(role);
      sounds.roleReveal();
    });
  }, [session, myRole, setMyRole]);

  const isCriminal = myRole === 'criminal';

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader phase="Role Assignment" title="Your Role" />

      <Card glow className="text-center animate-reveal">
        {myRole ? (
          <>
            <div className={`mb-4 text-6xl ${isCriminal ? 'text-vanchakan-red' : 'text-vanchakan-gold'}`}>
              {isCriminal ? '🎭' : '🔍'}
            </div>
            <h2 className={`mb-4 text-2xl font-bold ${isCriminal ? 'text-vanchakan-red' : 'text-vanchakan-gold'}`}>
              {isCriminal ? 'You are the Vanchakan.' : 'You are innocent.'}
            </h2>
            <p className="text-vanchakan-muted">
              {isCriminal
                ? 'You committed the crime. Convince everyone that the evidence does not point to you.'
                : 'Study the evidence, question the suspects, and identify the Vanchakan.'}
            </p>
          </>
        ) : (
          <p className="text-vanchakan-muted">Revealing your role...</p>
        )}
      </Card>
    </div>
  );
}
