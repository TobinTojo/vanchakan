import { cn } from '@/utils/storage';
import { usePreviousPhaseWarning } from '@/hooks/useGameTimer';
import { useEffect } from 'react';
import { sounds } from '@/utils/sounds';

interface GameTimerProps {
  remaining: number;
  total?: number;
  label?: string;
  warningThreshold?: number;
}

export function GameTimer({ remaining, total = 30, label, warningThreshold = 5 }: GameTimerProps) {
  const isWarning = usePreviousPhaseWarning(remaining, warningThreshold);
  const progress = total > 0 ? (remaining / total) * 100 : 0;

  useEffect(() => {
    if (isWarning) sounds.timerWarning();
  }, [isWarning]);

  return (
    <div className="flex flex-col items-center gap-2" role="timer" aria-live="polite" aria-label={`${remaining} seconds remaining`}>
      {label && <span className="text-sm text-vanchakan-muted">{label}</span>}
      <div className="relative flex h-16 w-16 items-center justify-center">
        <svg className="absolute h-full w-full -rotate-90" viewBox="0 0 36 36">
          <circle cx="18" cy="18" r="16" fill="none" stroke="currentColor" strokeWidth="2" className="text-vanchakan-border" />
          <circle
            cx="18"
            cy="18"
            r="16"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeDasharray={`${progress} 100`}
            className={cn(
              'transition-all duration-300 motion-reduce:transition-none',
              isWarning ? 'text-vanchakan-red' : 'text-vanchakan-purple'
            )}
          />
        </svg>
        <span className={cn('text-xl font-bold tabular-nums', isWarning && 'text-vanchakan-red animate-pulse')}>
          {remaining}
        </span>
      </div>
    </div>
  );
}
