import { useEffect, useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { PhaseHeader } from '@/components/common/PhaseHeader';
import { ART } from '@/assets/art';
import { useGame } from '@/context/GameContext';
import { getMyRole, advanceRoleRevealNow } from '@/services/gameService';
import { sounds } from '@/utils/sounds';
import { formatError } from '@/utils/storage';
import type { PlayerRole } from '@/types';

const ROLE_COPY: Record<
  Exclude<PlayerRole, 'unknown'>,
  { image: string; title: string; body: string; accent: string }
> = {
  criminal: {
    image: ART.roleVanchakan,
    title: 'You are the Vanchakan',
    body: 'You committed the crime. Convince everyone the evidence does not point to you.',
    accent: 'text-vanchakan-red',
  },
  innocent: {
    image: ART.roleInnocent,
    title: 'You are innocent',
    body: 'Study the evidence, question suspects, and identify the Vanchakan.',
    accent: 'text-vanchakan-gold',
  },
  jester: {
    image: ART.roleJester,
    title: 'You are the Jester',
    body: 'You win alone if the group accuses you in the final vote. Act suspicious — but don\'t make it obvious.',
    accent: 'text-vanchakan-purple-light',
  },
};

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

  const roleKey = myRole as Exclude<PlayerRole, 'unknown'>;
  const copy = myRole && myRole !== 'unknown' ? ROLE_COPY[roleKey] : null;

  return (
    <div className="mx-auto max-w-lg animate-fade-in">
      <PhaseHeader phase="Role Assignment" title="Your Role" />

      <Card glow className="text-center animate-reveal py-8 sm:py-10">
        {copy ? (
          <>
            <div className="mb-6 flex justify-center">
              <img
                src={copy.image}
                alt=""
                className="h-36 w-36 rounded-2xl object-cover ring-2 ring-white/10 sm:h-44 sm:w-44"
              />
            </div>
            <h2 className={`mb-4 text-3xl font-bold sm:text-4xl ${copy.accent}`}>{copy.title}</h2>
            <p className="mx-auto max-w-sm text-base leading-relaxed text-vanchakan-muted">{copy.body}</p>
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
