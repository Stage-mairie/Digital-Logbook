FROM node:24-bookworm-slim AS dependencies
WORKDIR /app
COPY backend/package.json backend/package-lock.json ./
# Outillage natif de secours si argon2 ne trouve pas de binaire précompilé.
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
RUN npm ci --omit=dev && npm cache clean --force

FROM node:24-bookworm-slim
ENV NODE_ENV=production
WORKDIR /app
COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node backend/package.json backend/package-lock.json ./
COPY --chown=node:node backend/src ./src
COPY --chown=node:node backend/sql ./sql
RUN mkdir -p vault && chown node:node vault
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
