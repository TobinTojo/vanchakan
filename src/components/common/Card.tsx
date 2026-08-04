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
        'rounded-xl border border-vanchakan-border bg-vanchakan-card p-6',
        glow && 'shadow-lg shadow-vanchakan-purple/10',
        className
      )}
    >
      {children}
    </div>
  );
}
