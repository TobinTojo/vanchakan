interface PhaseHeaderProps {
  title: string;
  subtitle?: string;
  phase?: string;
}

export function PhaseHeader({ title, subtitle, phase }: PhaseHeaderProps) {
  return (
    <header className="mb-6 text-center sm:mb-8">
      {phase && (
        <p className="mb-2 text-[10px] font-bold uppercase tracking-[0.2em] text-vanchakan-gold sm:text-xs">
          {phase}
        </p>
      )}
      <h1 className="font-display text-2xl font-bold leading-tight text-white sm:text-3xl md:text-4xl">
        {title}
      </h1>
      {subtitle && (
        <p className="mt-2 text-sm leading-relaxed text-vanchakan-muted sm:text-base">{subtitle}</p>
      )}
    </header>
  );
}
