# Atomic CRM — frontend dev server.
# Node 22 (matches .nvmrc) running the Vite dev server against the Supabase
# stack hosted by the sibling `supabase` (DinD) service.
FROM node:22-alpine

ENV REPO_DIR=/app \
    SHARED_DIR=/shared

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /app

EXPOSE 5173

ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]
