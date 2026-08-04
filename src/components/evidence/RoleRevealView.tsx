import { useEffect, useRef } from 'react';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { PhaseProgressBar } from '@/components/common/PhaseProgressBar';
import { ART } from '@/assets/art';
import { useGame } from '@/context/GameContext';
import { useSyncedGameTimer } from '@/hooks/useGameTimer';
import { getMyRole, advanceRoleRevealNow } from '@/services/gameService';
import { sounds } from '@/utils/sounds';
import { shouldDrivePhaseAdvance } from '@/utils/phaseAdvance';

const ROLE_REVEAL_SECONDS = 5;
const ADVANCE_INTERVAL_MS = 4000;

export function RoleRevealView() {
  const { session, room, players, myRole, setMyRole } = useGame();
  const { remaining, progress } = useSyncedGameTimer(ROLE_REVEAL_SECONDS, false, true);
  const advancingRef = useRef(false);
  const drivesAdvance = session ? shouldDrivePhaseAdvance(session.playerId, players) : false;

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
      if (!drivesAdvance || advancingRef.current) return;
      advancingRef.current = true;
      advanceRoleRevealNow(session.playerId, session.sessionToken)
        .catch(() => {})
        .finally(() => {
          advancingRef.current = false;
        });
    };

    if (remaining <= 0) {
      tryAdvance();
      const interval = setInterval(tryAdvance, ADVANCE_INTERVAL_MS);
      return () => clearInterval(interval);
    }
  }, [remaining, session, room?.status, drivesAdvance]);

  const isCriminal = myRole === 'criminal';

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader phase="Role Assignment" title="Your Role" />

      <Card glow className="text-center animate-reveal py-8 sm:py-10">
        {myRole ? (
          <>
            <div className="mb-6 flex justify-center">
              <img
                src={isCriminal ? ART.roleVanchakan : ART.roleInnocent}
                alt=""
                className="h-36 w-36 rounded-2xl object-cover ring-2 ring-white/10 sm:h-44 sm:w-44"
              />
            </div>
            <h2 className={`mb-4 text-3xl font-bold sm:text-4xl ${isCriminal ? 'text-vanchakan-red' : 'text-vanchakan-gold'}`}>
              {isCriminal ? 'You are the Vanchakan' : 'You are innocent'}
            </h2>
            <p className="mx-auto max-w-sm text-base leading-relaxed text-vanchakan-muted">
              {isCriminal
                ? 'You committed the crime. Convince everyone the evidence does not point to you.'
                : 'Study the evidence, question suspects, and identify the Vanchakan.'}
            </p>
            <p className="mt-6 text-sm font-medium text-vanchakan-purple-light">
              Remember your role — it stays visible in the top bar.
            </p>
          </>
        ) : (
          <p className="text-vanchakan-muted">Revealing your role...</p>
        )}
      </Card>

      <PhaseProgressBar
        progress={progress}
        label={remaining > 0 ? `Role revealed — continuing in ${remaining}s` : 'Revealing the crime...'}
      />
    </div>
  );
}
