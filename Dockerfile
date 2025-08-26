# ---- Stage 1: Build & Static Export (Node 22) ----
FROM node:22 AS builder
ENV CI=true

WORKDIR /app
RUN corepack enable

# Salin manifest untuk cache deps
COPY package.json ./
COPY package-lock.json* ./
COPY pnpm-lock.yaml* ./
COPY yarn.lock* ./

# Install deps sesuai lockfile
RUN if [ -f pnpm-lock.yaml ]; then pnpm install --frozen-lockfile; \
    elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
    else npm ci; fi

# Salin source dan build + export
COPY . .
# Pastikan next.config.js: output: 'export' (lihat catatan di bawah)
RUN if [ -f pnpm-lock.yaml ]; then pnpm run build && pnpm run export; \
    elif [ -f yarn.lock ]; then yarn build && yarn export; \
    else npm run build && npm run export; fi
# Hasil export: ./out


# ---- Stage 2: Runtime (Nginx Debian) ----
FROM nginx:latest AS runtime

# (Opsional) pakai config Nginx custom untuk SPA fallback & caching
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# Salin hasil static export
COPY --from=builder /app/out /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
