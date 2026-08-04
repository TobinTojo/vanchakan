interface PhaseProgressBarProps {
  progress: number;
  label?: string;
}

export function PhaseProgressBar({ progress, label }: PhaseProgressBarProps) {
  return (
    <div className="mx-auto mt-6 w-full max-w-xs" role="progressbar" aria-valuenow={Math.round(progress)} aria-valuemin={0} aria-valuemax={100}>
      {label && <p className="mb-2 text-center text-sm text-vanchakan-muted">{label}</p>}
      <div className="h-2 overflow-hidden rounded-full bg-vanchakan-border">
        <div
          className="h-full rounded-full bg-vanchakan-purple transition-all duration-300 ease-linear motion-reduce:transition-none"
          style={{ width: `${Math.min(100, Math.max(0, progress))}%` }}
        />
      </div>
    </div>
  );
}
