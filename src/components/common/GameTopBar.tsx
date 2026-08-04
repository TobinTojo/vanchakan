import { Link } from 'react-router-dom';
import { RoleBadge } from '@/components/common/RoleBadge';
import { SoundToggle } from '@/components/common/SoundToggle';

export function GameTopBar() {
  return (
    <header className="sticky top-0 z-20 -mx-4 mb-5 border-b border-white/5 bg-vanchakan-bg/90 px-4 py-2.5 backdrop-blur-md sm:-mx-0 sm:mb-6 sm:rounded-xl sm:border sm:px-4">
      <div className="flex items-center justify-between gap-2">
        <div className="flex min-w-0 items-center gap-2">
          <Link
            to="/"
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-vanchakan-purple/15 text-sm"
            aria-label="Home"
          >
            🎭
          </Link>
          <RoleBadge />
        </div>
        <SoundToggle />
      </div>
    </header>
  );
}
