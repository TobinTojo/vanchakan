/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        vanchakan: {
          bg: '#0a0612',
          surface: '#130d1c',
          card: '#1c1428',
          border: '#2e2040',
          purple: '#8b5cf6',
          'purple-light': '#a78bfa',
          red: '#f87171',
          gold: '#fbbf24',
          muted: '#9ca3af',
        },
      },
      fontFamily: {
        display: ['"Playfair Display"', 'Georgia', 'serif'],
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      backgroundImage: {
        'hero-glow':
          'radial-gradient(ellipse 80% 50% at 50% -20%, rgba(139,92,246,0.18), transparent), radial-gradient(ellipse 60% 40% at 100% 0%, rgba(251,191,36,0.06), transparent)',
        'card-shine': 'linear-gradient(135deg, rgba(255,255,255,0.04) 0%, transparent 50%)',
      },
      boxShadow: {
        card: '0 4px 24px -4px rgba(0,0,0,0.4), 0 0 0 1px rgba(255,255,255,0.04)',
        glow: '0 0 40px -8px rgba(139,92,246,0.35)',
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'fade-in': 'fadeIn 0.5s ease-out',
        'slide-up': 'slideUp 0.4s ease-out',
        reveal: 'reveal 0.6s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        reveal: {
          '0%': { opacity: '0', transform: 'scale(0.95) rotateX(10deg)' },
          '100%': { opacity: '1', transform: 'scale(1) rotateX(0)' },
        },
      },
    },
  },
  plugins: [],
};
