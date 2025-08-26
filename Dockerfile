# ---- Stage 1: Build & Export ----
FROM node:22-alpine AS builder

# Opsi: set timezone/locale bila perlu
ENV CI=true

# Pasang deps yg dibutuhkan untuk build native (jarang perlu untuk export, tapi aman)
RUN apk add --no-cache libc6-compat

WORKDIR /app

# Aktifkan corepack agar bisa pakai pnpm/yarn bila ada lock-nya
RUN corepack enable

# Salin manifest dulu untuk cache layer install deps
# (salin lockfile apa pun yang ada)
COPY package.json ./
COPY package-lock.json* ./
COPY pnpm-lock.yaml* ./
COPY yarn.lock* ./
# Jika memakai pnpm: aktifkan store dalam container agar cache layer efektif
ARG PNPM_HOME=/root/.local/share/pnpm
ENV PNPM_HOME=${PNPM_HOME} PATH=${PNPM_HOME}:$PATH

# Install deps sesuai lockfile yang terdeteksi
# Urutan prioritas: pnpm > yarn > npm
RUN if [ -f pnpm-lock.yaml ]; then pnpm install --frozen-lockfile; \
    elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
    else npm ci; fi

# Salin sisa source
COPY . .

# Build & export static
# Pastikan next.config.js memiliki: output: 'export' dan images: { unoptimized: true } bila perlu
RUN if [ -f pnpm-lock.yaml ]; then pnpm run build && pnpm run export; \
    elif [ -f yarn.lock ]; then yarn build && yarn export; \
    else npm run build && npm run export; fi
# Hasil export default ke ./out

# ---- Stage 2: Runtime (Nginx) ----
FROM nginx:alpine AS runtime

# Jalankan sebagai non-root (nginx image default user: nginx)
# Pastikan folder target dimiliki oleh user nginx
RUN mkdir -p /usr/share/nginx/html && chown -R nginx:nginx /usr/share/nginx/html

# (Opsional) Nginx config minimal untuk cache static & fallback 404/200
# Uncomment jika butuh SPA fallback (misal Anda pakai client-side routing tanpa file fisik)
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# Salin hasil export dari stage builder
COPY --from=builder /app/out /usr/share/nginx/html

USER nginx
EXPOSE 80

# Healthcheck sederhana
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1

CMD ["nginx", "-g", "daemon off;"]
