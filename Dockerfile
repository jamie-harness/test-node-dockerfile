# syntax=docker/dockerfile:1

FROM --platform=${TARGETPLATFORM:-linux/amd64} node:24-alpine AS base

ARG CI=true
ENV CI=$CI
ARG PR
ENV PR=$PR

# Network configuration with proper timeouts
ENV HTTP_PROXY=
ENV HTTPS_PROXY=
ENV NO_PROXY=
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Configure npm for slower networks and retries
RUN npm config set fetch-timeout 120000 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-retries 5 && \
    npm config set maxsockets 5

WORKDIR /app

COPY ./package.json ./
COPY ./package-lock.json ./

# -----------------------------------------------------------
FROM base AS deps

# npm ci with network resilience and offline preference
RUN npm ci --prefer-offline --no-audit --legacy-peer-deps || \
    npm ci --prefer-offline --no-audit --legacy-peer-deps && \
    npm cache clean -f && \
    # Remove unused SWC platform binaries to reduce image size
    for swc in $(find node_modules -type d -name 'swc-*' 2>/dev/null || true); do \
        if echo ${swc} | grep -q linux-x64-musl; then continue; fi; \
        rm -rf ${swc}; \
    done

COPY . .

# -----------------------------------------------------------
FROM deps AS build

# https://nextjs.org/telemetry
ENV NEXT_TELEMETRY_DISABLED=1

ARG NODE_ENV_ARG=production
ENV NODE_ENV=$NODE_ENV_ARG

RUN npm run build && \
    rm -rf node_modules && \
    npm ci --production --ignore-scripts --prefer-offline --no-audit --legacy-peer-deps && \
    npm cache clean -f && \
    # Remove unused SWC platform binaries to reduce image size
    for swc in $(find node_modules -type d -name 'swc-*' 2>/dev/null || true); do \
        if echo ${swc} | grep -q linux-x64-musl; then continue; fi; \
        rm -rf ${swc}; \
    done

# -----------------------------------------------------------
FROM --platform=${TARGETPLATFORM:-linux/amd64} node:24-alpine AS release

ARG CI=true
ENV CI=$CI
ARG PR
ENV PR=$PR

# https://nextjs.org/telemetry
ENV NEXT_TELEMETRY_DISABLED=1

ARG NODE_ENV_ARG=production
ENV NODE_ENV=$NODE_ENV_ARG

# Build metadata
ARG GIT_URL
ENV GIT_URL=$GIT_URL
LABEL GIT_URL=$GIT_URL

ARG BUILD_IMAGE
ENV BUILD_IMAGE=$BUILD_IMAGE
LABEL BUILD_IMAGE=$BUILD_IMAGE

ARG GIT_COMMIT
ENV GIT_COMMIT=$GIT_COMMIT
LABEL GIT_COMMIT=$GIT_COMMIT

ARG BUILD_URL
ENV BUILD_URL=$BUILD_URL
LABEL BUILD_URL=$BUILD_URL

ARG BUILD_DATE
ENV BUILD_DATE=$BUILD_DATE
LABEL BUILD_DATE=$BUILD_DATE

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

WORKDIR /app

# Copy built application from build stage
COPY --from=build --chown=nextjs:nodejs /app/ ./

USER nextjs

EXPOSE 3000

CMD ["npm", "start"]

