# Atomic CRM — Supabase service.
#
# Contains:
#   - the nested Docker daemon (docker:dind pulls in dockerd + the docker CLI).
#     The Supabase CLI orchestrates its whole stack inside THIS nested daemon,
#     so no container ever sees or touches the host Docker socket.
#   - Node.js + npm (for `npm install`, `npm run dev`, and the Supabase CLI).
#   - the Supabase CLI, pre-installed globally (the repo does not declare it,
#     so we install it here instead of relying on interactive `npx` prompts).
#   - /docker/supabase/start-supabase.sh as ENTRYPOINT: lazily installs and
#     boots the stack from the project's own official steps.
#
# IMPORTANT: compose runs this service with `privileged: true`. That is
# required by Docker-in-Docker's inner daemon — it does NOT expose the host
# daemon; the inner daemon and its containers live in a sandboxed namespace.

FROM docker:dind

# Node.js + npm + ca-certificates for TLS.
RUN apk add --no-cache nodejs npm ca-certificates && node --version

# Pin a reasonable Supabase CLI version. The repo does not pin one; 'latest' is
# fine for a local dev stack. List installed tags with: docker images (none,
# this is runtime-global) — pin here if a specific version is needed.
RUN npm install -g --no-fund --no-audit supabase

ENV REPO_DIR=/workspace \
    SHARED_DIR=/shared \
    SUPABASE_PROJECT_ID=atomic-crm-demo

COPY start-supabase.sh /usr/local/bin/start-supabase.sh
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start-supabase.sh /usr/local/bin/start.sh

WORKDIR /workspace

EXPOSE 54321 54322 54323 54324

# Use custom entrypoint that starts dockerd, then runs start-supabase.sh
ENTRYPOINT ["/usr/local/bin/start.sh"]
