interface ErrorBannerProps {
  message: string;
  onDismiss?: () => void;
}

export function ErrorBanner({ message, onDismiss }: ErrorBannerProps) {
  return (
    <div
      className="mb-4 rounded-lg border border-vanchakan-red/50 bg-vanchakan-red/10 px-4 py-3 text-vanchakan-red"
      role="alert"
    >
      <div className="flex items-center justify-between gap-2">
        <p>{message}</p>
        {onDismiss && (
          <button onClick={onDismiss} className="text-sm underline" aria-label="Dismiss error">
            Dismiss
          </button>
        )}
      </div>
    </div>
  );
}
