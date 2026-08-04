let audioContext: AudioContext | null = null;

function getContext(): AudioContext {
  if (!audioContext) {
    audioContext = new AudioContext();
  }
  return audioContext;
}

function playTone(frequency: number, duration: number, type: OscillatorType = 'sine', volume = 0.1): void {
  if (localStorage.getItem('vanchakan_sound_muted') === 'true') return;
  try {
    const ctx = getContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.value = frequency;
    gain.gain.value = volume;
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + duration);
  } catch {
    // Audio not available
  }
}

export const sounds = {
  join: () => playTone(523, 0.15),
  submit: () => playTone(659, 0.1),
  timerWarning: () => playTone(440, 0.2, 'square', 0.08),
  roleReveal: () => {
    playTone(220, 0.3, 'sawtooth', 0.06);
    setTimeout(() => playTone(330, 0.4, 'sawtooth', 0.06), 200);
  },
  evidenceReveal: () => playTone(784, 0.25),
  lieDetector: () => {
    playTone(300, 0.15, 'square');
    setTimeout(() => playTone(400, 0.15, 'square'), 150);
  },
  vote: () => playTone(550, 0.12),
  criminalReveal: () => {
    playTone(150, 0.5, 'sawtooth', 0.1);
    setTimeout(() => playTone(100, 0.6, 'sawtooth', 0.1), 300);
  },
};
