interface WaitingScreenProps {
  message?: string;
}

export function WaitingScreen({ message = 'Waiting for other players...' }: WaitingScreenProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 animate-fade-in">
      <div className="mb-4 h-10 w-10 animate-spin rounded-full border-4 border-vanchakan-purple border-t-transparent" />
      <p className="text-lg text-vanchakan-muted">{message}</p>
    </div>
  );
}
