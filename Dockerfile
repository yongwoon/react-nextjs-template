# docs.google.com/spreadsheets/d/125B6eMj5bOJDxHY-QIlOlu-9ajSQjJqBtD_3dbczEBs/edit#gid=0
# https://github.com/vercel/next.js/blob/canary/examples/with-docker/Dockerfile

# base ----------------------------------------------------------------------
FROM node:24.11.1-alpine AS base

FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
RUN mkdir -p /var/www
WORKDIR /var/www/

# Install dependencies based on the preferred package manager
COPY package.json package-lock.json ./
RUN npm ci

# builder ----------------------------------------------------------------------
FROM base AS builder

RUN mkdir -p /var/www
WORKDIR /var/www/
COPY --from=deps /var/www/node_modules ./node_modules
COPY . .

RUN npm run build

# runner ----------------------------------------------------------------------
FROM base AS runner

ENV NODE_ENV production
ENV PORT 3000
ENV HOSTNAME "0.0.0.0"
# ENV APP_ROOT /var/www
# ENV LANG=ja_JP.UTF-8
# ENV LANGUAGE=ja_JP.UTF-8
# ENV TZ=Asia/Tokyo

# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN apk add --no-cache mysql-client curl

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

RUN mkdir -p /var/www
WORKDIR /var/www/

COPY --from=builder /var/www/public ./public

RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /var/www/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /var/www/.next/static ./.next/static

USER nextjs

EXPOSE 3000

# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/next-config-js/output
CMD ["node", "server.js"]
