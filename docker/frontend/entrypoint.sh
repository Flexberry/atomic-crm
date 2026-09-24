#!/usr/bin/env sh
# Frontend (Vite dev server) entrypoint.
#
# Waits for the `supabase` service to publish /shared/.env.frontend (the API
# URL + publishable key the browser must use), loads it into the environment,
# then starts the Vite dev server. Vite gives real process-env vars precedence
# over .env files, so these values win over the repo's .env.development.
#
# The browser (not this server) calls the Supabase API; VITE_SUPABASE_URL is the
# host-visible API URL that compose publishes from the dinD stack.

set -eu

REPO="${REPO_DIR:-/app}"
SHARED="${SHARED_DIR:-/shared}"

# 1. Wait for the supabase service to publish its connection info.
echo "[frontend] waiting for /shared/.env.frontend from the supabase service..."
i=0
until [ -s "$SHARED/.env.frontend" ]; do
  i=$((i + 1))
  if [ "$i" -gt 120 ]; then
    echo "[frontend] supabase service did not publish .env.frontend in time" >&2
    exit 1
  fi
  sleep 2
done
echo "[frontend] connection info received:"
sed 's/=.*/=<set>/' "$SHARED/.env.frontend"

cd "$REPO"

# 2. Ensure deps (in case the supabase container didn't / this image is used
#    standalone). Idempotent.
if [ ! -d node_modules ]; then
  echo "[frontend] installing dependencies (npm install)..."
  npm install
fi

# 3. Source the published values so Vite picks them up.
set -a
# shellcheck disable=SC1090
. "$SHARED/.env.frontend"
set +a

# 4. Run the dev server, listening on all interfaces.
echo "[frontend] starting Vite dev server..."
exec npm run dev -- --host 0.0.0.0
