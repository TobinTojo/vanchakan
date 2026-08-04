import { Link } from 'react-router-dom';
import { ART } from '@/assets/art';
import { SoundToggle } from '@/components/common/SoundToggle';
import { cn } from '@/utils/storage';

interface NavbarProps {
  className?: string;
  onHowToPlay?: () => void;
}

export function Navbar({ className, onHowToPlay }: NavbarProps) {
  return (
    <nav
      className={cn(
        'sticky top-0 z-30 border-b border-white/5 bg-vanchakan-bg/80 backdrop-blur-md',
        className
      )}
    >
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 sm:px-6">
        <Link to="/" className="flex items-center gap-2.5 min-w-0">
          <img
            src={ART.logo}
            alt=""
            className="h-9 w-9 shrink-0 rounded-lg object-cover ring-1 ring-vanchakan-purple/30"
          />
          <div className="min-w-0">
            <p className="font-display text-lg font-bold leading-tight text-white sm:text-xl">Vanchakan</p>
            <p className="hidden text-[10px] uppercase tracking-wider text-vanchakan-muted sm:block">
              Social deduction
            </p>
          </div>
        </Link>

        <div className="flex items-center gap-2 sm:gap-4">
          {onHowToPlay && (
            <button
              type="button"
              onClick={onHowToPlay}
              className="hidden text-sm font-medium text-vanchakan-muted transition-colors hover:text-white sm:block"
            >
              How to Play
            </button>
          )}
          <SoundToggle />
        </div>
      </div>
    </nav>
  );
}
