# Atomic CRM — Docker Compose (lazy-install via Supabase CLI)

Run the whole Atomic CRM stack (frontend + a real Supabase backend) with Docker
Compose. **Nothing is installed or run on the host** — no Make, no Node, no npm,
no Supabase CLI. The only host tool is Docker with the Compose plugin.

## The approach

Instead of hand-declaring every Supabase micro-service, this stack reuses the
project's **own official setup steps** (the ones the project runs via `make
install` / `make start`), but executes them **inside a container**:

1. A `supabase` service runs the **official Supabase CLI inside a nested Docker
   daemon** (`docker:dind`).
2. On first start its `start-supabase.sh` checks whether a stack already exists
   (reuses it if so). If not, it performs the official install:
   - `npm install` (if `node_modules` is absent),
   - `npx supabase start` (boots Supabase + applies migrations + seed),
   - guarantees `supabase migration up` is applied (idempotent).
3. It then writes the concrete API URL + publishable key to a shared volume,
   which the `frontend` service reads before starting the Vite dev server.

All commands above run **inside the containers**; `make` is never invoked.

**Security:** the Supabase CLI orchestrates its stack inside a *nested* Docker
daemon, so **no container is ever given the host Docker socket**. The only
privileged flag is on the `supabase` service itself and is required by the inner
`dockerd` — it does not expose the host daemon.

## Requirements

- Docker Engine `>= 24` with Compose v2 (`docker compose`). No other host tools.

## Run

From the `docker/` directory:

```sh
docker compose build      # build images (one-time)
docker compose up -d      # start the stack
```

First run takes several minutes (downloads images, boots the nested stack).
Follow the lazy install:

```sh
docker compose logs -f supabase
```

Until you see:

```
[supabase] Supabase stack is up. Keeping container alive.
```

Then open **http://localhost:5173** and create the first user.

| URL | Service |
| --- | --- |
| http://localhost:5173  | Frontend (Vite) |
| http://localhost:54321 | Supabase API (REST/Auth/Storage via CLI stack) |
| http://localhost:54323 | Supabase Studio |
| localhost:54322        | Postgres |
| http://localhost:54324 | Inbucket (email) |

## Idempotence / reusing the running stack

The `docker-data` and `shared` volumes persist. On `docker compose up` again,
`start-supabase.sh` detects the already-running stack (via `supabase status`),
skips installation, and just republishes the connection info. `npm install` only
runs once (when `node_modules` is missing).

## Managing

```sh
docker compose ps                       # container state
docker compose logs -f                  # all logs
docker compose down                     # stop (keep data volumes)
docker compose down -v                  # stop AND delete all volumes (fresh start)
```

## Troubleshooting

- **`supabase` service exits early**: check `docker compose logs supabase`. The
  nested daemon needs `privileged: true` (set) and enough memory/disk.
- **Inner daemon can't start on Windows/WSL2**: Docker Desktop must be running
  and be the active engine. DinD inside Docker Desktop is supported; if the
  nested daemon fails, run `docker compose down -v` and retry.
- **First `supabase start` needs a bootstrapped CLI**: the image pre-installs
  `supabase` globally, so no interactive `npx` prompt occurs. If the repo later
  pins a version, align `docker/supabase/Dockerfile`.
- **Port already in use**: the stack publishes 5173/54321–54324. Free them or
  edit the `ports:` mapping in `docker/docker-compose.yml`.

## Layout

```
docker/
├── docker-compose.yml      services: supabase (DinD+CLI), frontend (Vite)
├── README.md               this file
├── supabase/
│   ├── Dockerfile          docker:dind + Node + Supabase CLI + start script
│   └── start-supabase.sh   lazy-install logic (the heart)
└── frontend/
    ├── Dockerfile          node:22-alpine
    └── entrypoint.sh       waits for /shared/.env.frontend, starts Vite
```
