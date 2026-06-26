FROM node:22-bookworm-slim AS dependencies

WORKDIR /app

ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_FACTOR=2 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000 \
    NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000 \
    NPM_CONFIG_FETCH_TIMEOUT=300000

COPY package.json package-lock.json ./
# Core compiles with TypeScript only. Skipping dependency lifecycle scripts avoids
# Docker Desktop file-lock races in transitive tooling such as esbuild.
RUN --mount=type=cache,target=/root/.npm \
    npm ci --ignore-scripts --no-audit --no-fund

FROM dependencies AS builder

COPY . .
RUN npm run build

FROM dependencies AS production-dependencies

RUN npm prune --omit=dev --ignore-scripts \
    && npm cache clean --force

FROM node:22-bookworm-slim AS runtime

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

RUN groupadd --system --gid 10001 orbi \
    && useradd --system --uid 10001 --gid orbi --home-dir /app --shell /usr/sbin/nologin orbi

COPY --chown=orbi:orbi package.json package-lock.json ./
COPY --chown=orbi:orbi --from=production-dependencies /app/node_modules ./node_modules
COPY --chown=orbi:orbi --from=builder /app/dist ./dist
COPY --chown=orbi:orbi --from=builder /app/public ./public

USER orbi

EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:3000/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "dist/server.js"]
