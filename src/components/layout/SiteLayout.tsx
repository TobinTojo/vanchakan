import { Navbar } from '@/components/layout/Navbar';

interface SiteLayoutProps {
  children: React.ReactNode;
  onHowToPlay?: () => void;
}

export function SiteLayout({ children, onHowToPlay }: SiteLayoutProps) {
  return (
    <div className="min-h-screen bg-vanchakan-bg">
      <div className="pointer-events-none fixed inset-0 bg-hero-glow" aria-hidden="true" />
      <Navbar onHowToPlay={onHowToPlay} />
      <main className="relative">{children}</main>
    </div>
  );
}
