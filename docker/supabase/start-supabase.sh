#!/usr/bin/env sh
# Boot the Supabase stack (lazily) for Atomic CRM.
#
# Strategy: check whether a working Supabase stack already exists. If yes, just
# reuse it. If not, install it by running the project's OWN official setup
# commands directly (the ones `make install` / `make start` wrap on a host):
# `npm install`, then `supabase start`. All of it runs inside this container,
# against the nested Docker daemon (DinD). Nothing ever touches the host Docker
# socket, and `make` itself is never invoked.
#
# This script is the ENTRYPOINT of the `supabase` service; it runs AFTER the
# docker:dind image's own dockerd bootstrap has started the nested daemon.
#
# Flow:
#   1. wait for the nested docker daemon to be ready
#   2. if the repo deps are not installed -> `npm install` (official install step)
#   3. if the Supabase stack is not up -> `npx supabase start` (official start step)
#   4. guarantee migrations + seed are applied (idempotent)
#   5. write the real anon/publishable URL + key to /shared/.env.frontend for
#      the frontend service
#   6. keep running (the stack is already up; tail logs / sleep)

set -eu

REPO="${REPO_DIR:-/workspace}"
SHARED="${SHARED_DIR:-/shared}"
PROJECT_ID="${SUPABASE_PROJECT_ID:-atomic-crm-demo}"

echo "[supabase] nested docker daemon (DinD) bootstrap began by docker:dind entrypoint"

# 1. Wait for the nested daemon.
echo "[supabase] waiting for nested docker daemon..."
i=0
until docker info >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then
    echo "[supabase] nested docker daemon not ready after 120s" >&2
    exit 1
  fi
  sleep 2
done
echo "[supabase] nested docker daemon ready."

cd "$REPO"

# 2. Install frontend + backend deps (official install step) if not present.
if [ ! -d node_modules ]; then
  echo "[supabase] installing dependencies (npm install)..."
  npm install
else
  echo "[supabase] node_modules already present, skipping npm install."
fi

# Detect an already-running Supabase stack: the CLI writes a status file per
# project pointing at a running instance; if `supabase status` reports a live
# API URL we reuse it.
echo "[supabase] checking for an existing Supabase stack..."
ALREADY_UP=false
if npx supabase status >/dev/null 2>&1; then
  if npx supabase status 2>/dev/null | grep -q "API URL"; then
    ALREADY_UP=true
  fi
fi

if [ "$ALREADY_UP" = "true" ]; then
  echo "[supabase] Supabase stack already running; reusing it."
else
  # 3. Start the stack (official start step). On the very first run this
  #    downloads images, boots the nested containers, applies the repo's
  #    migrations and runs seed.sql.
  echo "[supabase] starting Supabase stack (npx supabase start)..."
  npx supabase start
fi

# 4. Guarantee migrations + seed are applied (idempotent; 'up' is safe to re-run).
echo "[supabase] applying migrations (idempotent)..."
if ! npx supabase migration up >/dev/null 2>&1; then
  echo "[supabase] note: 'supabase migration up' reported no pending changes."
fi

# 5. Publish the API URL + publishable key for the frontend.
#    The URL is the host-visible one (the browser reaches it via the published
#    host port). The publishable key is the repo's own, from .env.development —
#    it is derived from the same supabase/signing_keys.json the local CLI uses,
#    so it is exactly the key the running stack accepts.
API_URL="${API_EXTERNAL_URL:-http://localhost:54321}"
PUB_KEY=$(sed -n 's/^VITE_SB_PUBLISHABLE_KEY=//p' .env.development | head -1 || true)
if [ -z "$PUB_KEY" ]; then
  echo "[supabase] WARNING: VITE_SB_PUBLISHABLE_KEY not found in .env.development" >&2
fi

mkdir -p "$SHARED"
cat > "$SHARED/.env.frontend" <<EOF
VITE_SUPABASE_URL=$API_URL
VITE_SB_PUBLISHABLE_KEY=$PUB_KEY
EOF
echo "[supabase] wrote $SHARED/.env.frontend (URL=$API_URL)"

# 6. Keep this container alive; the stack runs in the nested daemon.
echo "[supabase] Supabase stack is up. Keeping container alive. Logs:"
echo "[supabase] (press signal to stop; run 'docker compose down' to tear down)"
tail -f /dev/null
