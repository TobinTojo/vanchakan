import { useEffect, useRef } from 'react';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PhaseProgressBar } from '@/components/common/PhaseProgressBar';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { getMyRole, advanceRoleRevealNow } from '@/services/gameService';
import { sounds } from '@/utils/sounds';

const ROLE_REVEAL_SECONDS = 8;

export function RoleRevealView() {
  const { session, room, myRole, setMyRole } = useGame();
  const { remaining, progress } = useSyncedGameTimer(ROLE_REVEAL_SECONDS, false);
  const advancingRef = useRef(false);

  useEffect(() => {
    if (!session || myRole) return;
    getMyRole(session.playerId, session.sessionToken).then((role) => {
      setMyRole(role);
      sounds.roleReveal();
    });
  }, [session, myRole, setMyRole]);

  useEffect(() => {
    if (!session || !room || room.status !== 'role_reveal') return;

    const tryAdvance = () => {
      if (advancingRef.current) return;
      advancingRef.current = true;
      advanceRoleRevealNow(session.playerId, session.sessionToken)
        .catch(() => {})
        .finally(() => {
          advancingRef.current = false;
        });
    };

    if (remaining <= 0) {
      tryAdvance();
      const interval = setInterval(tryAdvance, 2000);
      return () => clearInterval(interval);
    }
  }, [remaining, session, room?.status]);

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

      <PhaseProgressBar
        progress={progress}
        label={remaining > 0 ? `Continuing in ${remaining}s...` : 'Revealing the crime...'}
      />
    </div>
  );
}
