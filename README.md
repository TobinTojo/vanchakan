# Vanchakan

A multiplayer social deduction web game for 3–8 players. Answer survey questions, investigate evidence, interrogate suspects, and catch the **Vanchakan** — the player who committed a ridiculous crime.

## Tech Stack

- **Frontend:** React + Vite + TypeScript + Tailwind CSS
- **Backend:** Supabase (PostgreSQL + Realtime)
- **Auth:** Anonymous guest sessions (no account required)
- **Deploy:** Netlify

## Quick Start

### 1. Clone and install

```bash
cd vanchakan
npm install
```

### 2. Set up Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. Run the SQL migrations in order:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_seed_data.sql`
3. Enable **Realtime** for all game tables (done in migration)
4. Copy your project URL and anon key

### 3. Configure environment

```bash
cp .env.example .env
```

Edit `.env`:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_DEV_MODE=false
```

### 4. Run locally

```bash
npm run dev
```

Open `http://localhost:5173`

## How to Play

1. **Create or join** a room with a 6-character code
2. **Lobby** — wait for 3–8 players, host starts the game
3. **Survey** — answer 8 questions (7 multiple choice + 1 short answer)
4. **Role reveal** — you are innocent or the Vanchakan
5. **Crime reveal** — a ridiculous crime is announced
6. **Fake evidence** — one innocent player plants a red herring
7. **Evidence board** — study 8 clues (7 real, 1 fake)
8. **Interrogation** — 6 rounds of questioning suspects
9. **Lie detector** — after rounds 3 and 6, vote to inspect evidence or check answers
10. **Suspect vote** — pick your top 2 suspects
11. **Final vote** — accuse one player
12. **Results** — did you catch the Vanchakan?

## Developer Mode

Set `VITE_DEV_MODE=true` to enable a dev panel with:
- Force game tick (skip timers)
- View current phase and role
- Debug game state

## Deploy to Netlify

Vanchakan is a static frontend — Supabase handles the backend. You only deploy the built `dist` folder.

### 1. Supabase env vars

In Netlify, go to **Site settings → Environment variables** and add:

| Variable | Value |
|----------|-------|
| `VITE_SUPABASE_URL` | Your Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | Your Supabase anon key |
| `VITE_DEV_MODE` | `false` |

These must be set **before** the first build (Vite bakes them in at build time).

### 2. Deploy from Git (recommended)

1. Push this repo to GitHub or GitLab
2. Netlify → **Add new site → Import an existing project**
3. Select the repo — Netlify reads `netlify.toml` automatically:
   - Build command: `npm run build`
   - Publish directory: `dist`
4. Add the env vars from step 1
5. Click **Deploy site**

Room links like `/room/ABC123` work via SPA routing in `netlify.toml`.

### 3. Manual deploy (optional)

```bash
npm install
npm run build
```

Drag the `dist` folder into Netlify's deploy drop zone. You still need env vars set if you rebuild locally with a `.env` file.

## Project Structure

```
src/
  components/     # UI components by game phase
  pages/          # Home, Room, Join
  context/        # Game and sound state
  hooks/          # Timers and utilities
  services/       # Supabase RPC calls
  types/          # TypeScript interfaces
  data/           # Question and crime banks (reference)
  lib/            # Supabase client
  utils/          # Storage, sounds, helpers
supabase/
  migrations/     # SQL schema, RLS, RPC functions, seed data
```

## Security

- Criminal role is only exposed via the `get_my_role()` RPC (session-validated)
- Fake evidence `is_fake` flag is hidden until inspection or results
- All game actions go through PostgreSQL functions with session token validation
- Row Level Security prevents direct client writes
- Host-only actions validated server-side

## Multiplayer Testing

1. Open multiple browser tabs or use incognito windows
2. Create a room in one tab, join with others using the room code
3. Enable `VITE_DEV_MODE=true` to skip timers during testing

## License

MIT
