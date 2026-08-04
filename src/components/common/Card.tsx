import { cn } from '@/utils/storage';

interface CardProps {
  children: React.ReactNode;
  className?: string;
  glow?: boolean;
}

export function Card({ children, className, glow }: CardProps) {
  return (
    <div
      className={cn(
        'rounded-2xl border border-vanchakan-border/80 bg-vanchakan-card bg-card-shine p-5 shadow-card sm:p-6',
        glow && 'shadow-glow border-vanchakan-purple/30',
        className
      )}
    >
      {children}
    </div>
  );
}
