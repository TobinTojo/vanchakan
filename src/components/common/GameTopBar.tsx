import { RoleBadge } from '@/components/common/RoleBadge';
import { SoundToggle } from '@/components/common/SoundToggle';

export function GameTopBar() {
  return (
    <div className="sticky top-0 z-20 -mx-4 mb-6 flex items-center justify-between gap-2 border-b border-vanchakan-border/40 bg-vanchakan-bg/95 px-4 py-2 backdrop-blur sm:-mx-0 sm:rounded-lg sm:border sm:px-3">
      <RoleBadge />
      <div className="ml-auto">
        <SoundToggle />
      </div>
    </div>
  );
}
