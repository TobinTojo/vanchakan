import { useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { Modal } from '@/components/common/Modal';
import { ART } from '@/assets/art';
import { useGame } from '@/context/GameContext';
import { cn } from '@/utils/storage';

const PHASES_WITH_ROLE = new Set([
  'crime_reveal',
  'fake_evidence',
  'evidence',
  'interrogation',
  'lie_detector',
  'suspect_vote',
  'final_vote',
  'tie_breaker',
  'results',
  'finished',
]);

const ROLE_INFO = {
  criminal: {
    label: 'Vanchakan',
    image: ART.roleVanchakan,
    title: 'You are the Vanchakan',
    summary: 'You committed the crime. Convince everyone the evidence does not point to you.',
    tips: [
      'Your survey answers appear as genuine evidence on the board.',
      'One innocent player\'s answer was planted as fake evidence — it is not yours.',
      'Defend yourself during interrogation without giving yourself away.',
      'Survive the final vote to win.',
    ],
    accent: 'text-vanchakan-red',
    border: 'border-vanchakan-red/50 bg-vanchakan-red/15 text-vanchakan-red',
  },
  jester: {
    label: 'Jester',
    image: ART.roleJester,
    title: 'You are the Jester',
    summary: 'Win alone by getting the final vote. Detectives and Vanchakan both lose if you succeed.',
    tips: [
      'Answer the survey like anyone else — your answers still become evidence.',
      'Act suspicious enough to land in suspect talks without making your goal obvious.',
      'Hope the group accuses you in the final vote, not just the suspect round.',
      'If you are final accused, you win — nobody else does.',
    ],
    accent: 'text-vanchakan-purple-light',
    border: 'border-vanchakan-purple/50 bg-vanchakan-purple/15 text-vanchakan-purple-light',
  },
  innocent: {
    label: 'Innocent',
    image: ART.roleInnocent,
    title: 'You are innocent',
    summary: 'Study the evidence, question suspects, and identify the Vanchakan.',
    tips: [
      'Real evidence matches the criminal\'s survey answers.',
      'Fake evidence is a red herring from another innocent player.',
      'Use interrogation and the lie detector to spot dishonest answers.',
      'Vote correctly in the final round to win.',
    ],
    accent: 'text-vanchakan-gold',
    border: 'border-vanchakan-gold/50 bg-vanchakan-gold/15 text-vanchakan-gold',
  },
} as const;

export function RoleBadge() {
  const { room, myRole } = useGame();
  const [open, setOpen] = useState(false);

  if (!myRole || !room || !PHASES_WITH_ROLE.has(room.status)) return null;
  if (myRole !== 'criminal' && myRole !== 'innocent' && myRole !== 'jester') return null;

  const info = ROLE_INFO[myRole as keyof typeof ROLE_INFO];

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={cn(
          'flex shrink-0 items-center gap-1 rounded-full border px-2 py-1 text-[10px] font-semibold transition hover:brightness-110 sm:gap-1.5 sm:px-2.5 sm:text-xs',
          info.border
        )}
        aria-label={`Your role: ${info.label}. Click for details.`}
      >
        <img
          src={info.image}
          alt=""
          className="h-5 w-5 shrink-0 rounded-full object-cover ring-1 ring-white/20 sm:h-6 sm:w-6"
        />
        <span className="leading-none">{info.label}</span>
      </button>

      <Modal open={open} onClose={() => setOpen(false)} labelledBy="role-popup-title">
        <Card glow className="text-center">
          <img
            src={info.image}
            alt=""
            className="mx-auto mb-4 h-28 w-28 rounded-2xl object-cover ring-2 ring-white/10"
          />
          <h2 id="role-popup-title" className={cn('mb-2 text-2xl font-bold', info.accent)}>
            {info.title}
          </h2>
          <p className="mb-5 text-sm leading-relaxed text-vanchakan-muted">{info.summary}</p>
          <ul className="mb-6 space-y-2 text-left text-sm text-white/90">
            {info.tips.map((tip) => (
              <li key={tip} className="flex gap-2">
                <span className="shrink-0 text-vanchakan-purple-light">•</span>
                <span>{tip}</span>
              </li>
            ))}
          </ul>
          <Button onClick={() => setOpen(false)} className="w-full">
            Got it
          </Button>
        </Card>
      </Modal>
    </>
  );
}
