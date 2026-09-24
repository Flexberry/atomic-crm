#!/usr/bin/env sh
# Custom entrypoint for supabase service.
# Starts dockerd in background, then runs start-supabase.sh.

set -e

# Start dockerd in background
echo "[supabase] starting dockerd..."
dockerd > /tmp/dockerd.log 2>&1 &
DOCKERD_PID=$!

# Wait for dockerd to be ready
echo "[supabase] waiting for dockerd to be ready..."
i=0
until docker info >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then
    echo "[supabase] dockerd not ready after 120s" >&2
    echo "[supabase] dockerd log:" >&2
    cat /tmp/dockerd.log >&2
    exit 1
  fi
  echo "[supabase] waiting for dockerd... ($i/60)"
  sleep 2
done
echo "[supabase] dockerd is ready."

# Run the main start script
exec /usr/local/bin/start-supabase.sh
