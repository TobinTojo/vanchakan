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
    primary: 'bg-vanchakan-purple hover:bg-vanchakan-purple-light text-white shadow-lg shadow-vanchakan-purple/30',
    secondary: 'bg-vanchakan-card hover:bg-vanchakan-border text-white border border-vanchakan-border',
    danger: 'bg-vanchakan-red hover:bg-red-600 text-white',
    ghost: 'bg-transparent hover:bg-vanchakan-card text-vanchakan-muted hover:text-white',
  };

  const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-5 py-2.5 text-base',
    lg: 'px-8 py-3.5 text-lg',
  };

  return (
    <button
      className={cn(
        'inline-flex items-center justify-center gap-2 rounded-lg font-semibold transition-all',
        'focus:outline-none focus:ring-2 focus:ring-vanchakan-purple focus:ring-offset-2 focus:ring-offset-vanchakan-bg',
        'disabled:opacity-50 disabled:cursor-not-allowed',
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
