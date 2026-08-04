import { cn } from '@/utils/storage';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
}

export function Button({
  children,
  variant = 'primary',
  size = 'md',
  loading,
  className,
  disabled,
  ...props
}: ButtonProps) {
  const variants = {
    primary:
      'bg-vanchakan-purple hover:bg-vanchakan-purple-light text-white shadow-lg shadow-vanchakan-purple/25 active:scale-[0.98]',
    secondary:
      'bg-vanchakan-surface hover:bg-vanchakan-border/50 text-white border border-vanchakan-border active:scale-[0.98]',
    danger: 'bg-vanchakan-red hover:bg-red-500 text-white active:scale-[0.98]',
    ghost: 'bg-transparent hover:bg-vanchakan-surface text-vanchakan-muted hover:text-white',
  };

  const sizes = {
    sm: 'px-3 py-2 text-sm',
    md: 'px-5 py-2.5 text-base',
    lg: 'px-6 py-3.5 text-base sm:text-lg',
  };

  return (
    <button
      className={cn(
        'inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition-all',
        'focus:outline-none focus:ring-2 focus:ring-vanchakan-purple focus:ring-offset-2 focus:ring-offset-vanchakan-bg',
        'disabled:opacity-50 disabled:cursor-not-allowed disabled:active:scale-100',
        'motion-reduce:transition-none',
        variants[variant],
        sizes[size],
        className
      )}
      disabled={disabled || loading}
      {...props}
    >
      {loading && (
        <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
      )}
      {children}
    </button>
  );
}
