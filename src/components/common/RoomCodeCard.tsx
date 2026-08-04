import { Button } from './Button';
import { copyToClipboard, getInviteLink } from '@/utils/storage';
import { useState } from 'react';

interface RoomCodeCardProps {
  roomCode: string;
}

export function RoomCodeCard({ roomCode }: RoomCodeCardProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await copyToClipboard(getInviteLink(roomCode));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="rounded-xl border border-vanchakan-gold/30 bg-vanchakan-surface p-4 text-center">
      <p className="text-sm text-vanchakan-muted">Room Code</p>
      <p className="my-2 font-mono text-3xl font-bold tracking-[0.3em] text-vanchakan-gold">{roomCode}</p>
      <Button variant="secondary" size="sm" onClick={handleCopy}>
        {copied ? 'Copied!' : 'Copy Invite Link'}
      </Button>
    </div>
  );
}
