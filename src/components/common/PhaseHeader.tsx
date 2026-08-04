interface PhaseHeaderProps {
  title: string;
  subtitle?: string;
  phase?: string;
}

export function PhaseHeader({ title, subtitle, phase }: PhaseHeaderProps) {
  return (
    <header className="mb-6 text-center">
      {phase && (
        <p className="mb-1 text-xs font-semibold uppercase tracking-widest text-vanchakan-gold">
          {phase}
        </p>
      )}
      <h1 className="font-display text-3xl font-bold text-white md:text-4xl">{title}</h1>
      {subtitle && <p className="mt-2 text-vanchakan-muted">{subtitle}</p>}
    </header>
  );
}
