import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { GameProvider } from '@/context/GameContext';
import { SoundProvider } from '@/context/SoundContext';
import { HomePage } from '@/pages/HomePage';
import { RoomPage } from '@/pages/RoomPage';
import { JoinPage } from '@/pages/JoinPage';
import '@/styles/index.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <SoundProvider>
        <GameProvider>
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/room/:code" element={<RoomPage />} />
            <Route path="/join/:code" element={<JoinPage />} />
          </Routes>
        </GameProvider>
      </SoundProvider>
    </BrowserRouter>
  </StrictMode>
);
