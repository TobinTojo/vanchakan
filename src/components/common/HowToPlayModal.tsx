import { useState } from 'react';
import { Button } from '@/components/common/Button';
import { Card } from '@/components/common/Card';
import { Modal } from '@/components/common/Modal';
import { cn } from '@/utils/storage';

const SLIDES = [
  {
    title: 'Gather your suspects',
    body: '3–8 players join a private room using a 6-character code. One person hosts — everyone else joins with the code.',
    icon: '👥',
  },
  {
    title: 'Answer the survey',
    body: 'Everyone answers 8 personal questions. Your responses become evidence on the board — so answer honestly (or don\'t).',
    icon: '📝',
  },
  {
    title: 'Secret roles',
    body: 'One player is secretly the Vanchakan (the criminal). Everyone else is an innocent detective trying to catch them.',
    icon: '🎭',
  },
  {
    title: 'Investigate',
    body: 'Study the evidence board, interrogate suspects, and use the lie detector to spot dishonest answers. One clue is fake!',
    icon: '🔍',
  },
  {
    title: 'Vote to accuse',
    body: 'Nominate your top two suspects, then cast a final vote. If the group ties, you get a tie-breaker round.',
    icon: '🗳️',
  },
  {
    title: 'Catch the Vanchakan',
    body: 'Accuse the real Vanchakan and the detectives win. Accuse the wrong person and the criminal escapes!',
    icon: '🏆',
  },
];

interface HowToPlayModalProps {
  open: boolean;
  onClose: () => void;
}

export function HowToPlayModal({ open, onClose }: HowToPlayModalProps) {
  const [slide, setSlide] = useState(0);

  const handleClose = () => {
    setSlide(0);
    onClose();
  };

  const current = SLIDES[slide];
  const isFirst = slide === 0;
  const isLast = slide === SLIDES.length - 1;

  return (
    <Modal open={open} onClose={handleClose} labelledBy="how-to-play-title">
      <Card glow className="relative">
        <button
          type="button"
          onClick={handleClose}
          className="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-lg text-vanchakan-muted transition hover:bg-white/5 hover:text-white"
          aria-label="Close"
        >
          ✕
        </button>

        <div className="mb-6 pr-8">
          <p className="text-xs font-semibold uppercase tracking-wider text-vanchakan-purple-light">
            How to Play
          </p>
          <p className="mt-1 text-xs text-vanchakan-muted">
            Step {slide + 1} of {SLIDES.length}
          </p>
        </div>

        <div className="mb-6 min-h-[180px] text-center animate-fade-in" key={slide}>
          <div className="mb-4 text-5xl">{current.icon}</div>
          <h2 id="how-to-play-title" className="mb-3 font-display text-xl font-bold text-white sm:text-2xl">
            {current.title}
          </h2>
          <p className="mx-auto max-w-sm text-sm leading-relaxed text-vanchakan-muted">
            {current.body}
          </p>
        </div>

        <div className="mb-6 flex justify-center gap-2">
          {SLIDES.map((_, i) => (
            <button
              key={i}
              type="button"
              onClick={() => setSlide(i)}
              className={cn(
                'h-2 rounded-full transition-all',
                i === slide ? 'w-6 bg-vanchakan-purple' : 'w-2 bg-vanchakan-border hover:bg-vanchakan-purple/50'
              )}
              aria-label={`Go to step ${i + 1}`}
            />
          ))}
        </div>

        <div className="flex gap-3">
          <Button
            variant="secondary"
            onClick={() => setSlide((s) => s - 1)}
            disabled={isFirst}
            className="flex-1"
          >
            Back
          </Button>
          {isLast ? (
            <Button onClick={handleClose} className="flex-1">
              Got it
            </Button>
          ) : (
            <Button onClick={() => setSlide((s) => s + 1)} className="flex-1">
              Next
            </Button>
          )}
        </div>
      </Card>
    </Modal>
  );
}
