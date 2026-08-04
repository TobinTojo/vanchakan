import { cn } from '@/utils/storage';

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export function Input({ label, error, className, id, ...props }: InputProps) {
  const inputId = id || label?.toLowerCase().replace(/\s/g, '-');
  return (
    <div className="w-full">
      {label && (
        <label htmlFor={inputId} className="mb-1.5 block text-sm font-medium text-vanchakan-muted">
          {label}
        </label>
      )}
      <input
        id={inputId}
        className={cn(
          'w-full rounded-lg border border-vanchakan-border bg-vanchakan-surface px-4 py-3',
          'text-white placeholder:text-vanchakan-muted/60',
          'focus:border-vanchakan-purple focus:outline-none focus:ring-2 focus:ring-vanchakan-purple/30',
          error && 'border-vanchakan-red',
          className
        )}
        {...props}
      />
      {error && <p className="mt-1 text-sm text-vanchakan-red">{error}</p>}
    </div>
  );
}
