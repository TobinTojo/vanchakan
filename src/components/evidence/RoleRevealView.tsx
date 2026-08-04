import { useEffect, useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { ART } from '@/assets/art';
import { useGame } from '@/context/GameContext';
import { getMyRole, advanceRoleRevealNow } from '@/services/gameService';
import { sounds } from '@/utils/sounds';
import { formatError } from '@/utils/storage';

export function RoleRevealView() {
  const { session, room, myRole, setMyRole, isHost } = useGame();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!session || myRole) return;
    getMyRole(session.playerId, session.sessionToken).then((role) => {
      setMyRole(role);
      sounds.roleReveal();
    });
  }, [session, myRole, setMyRole]);

  const handleContinue = async () => {
    if (!session) return;
    setLoading(true);
    setError(null);
    try {
      await advanceRoleRevealNow(session.playerId, session.sessionToken);
    } catch (e) {
      setError(formatError(e));
    } finally {
      setLoading(false);
    }
  };

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
              Remember your role — tap the badge in the top bar anytime for a reminder.
            </p>
          </>
        ) : (
          <p className="text-vanchakan-muted">Revealing your role...</p>
        )}
      </Card>

      {room?.status === 'role_reveal' && myRole && (
        <div className="mt-6">
          {isHost ? (
            <>
              <Button onClick={handleContinue} loading={loading} size="lg" className="w-full">
                Reveal the Crime
              </Button>
              {error && <p className="mt-2 text-center text-sm text-vanchakan-red">{error}</p>}
            </>
          ) : (
            <p className="text-center text-sm text-vanchakan-muted">
              Waiting for the host to continue...
            </p>
          )}
        </div>
      )}
    </div>
  );
}
