# --- React build stage ---
FROM node:20-alpine AS react-build

WORKDIR /app

COPY ui/frontend/package*.json ./
RUN npm ci

COPY ui/frontend/ .
RUN npm run build

# --- Hugo build stage ---
FROM hugomods/hugo:std AS hugo-build

# Install python3, pip, and git (same CA workaround as repo root Dockerfile)
RUN apk --no-cache --allow-untrusted \
    --repository http://dl-cdn.alpinelinux.org/alpine/v3.21/main \
    add ca-certificates && \
    update-ca-certificates && \
    sed -i 's|https://dl-cdn.alpinelinux.org|http://dl-cdn.alpinelinux.org|g' /etc/apk/repositories && \
    apk update && \
    apk add --no-cache python3 py3-pip git

# Clone CentralRepo including theme submodule
RUN git clone --depth=1 --recurse-submodules --shallow-submodules --branch main \
    https://github.com/FortinetCloudCSE/CentralRepo.git \
    /home/CentralRepo

# Copy user repo files into UserRepo locations
COPY scripts/ /home/UserRepo/scripts/
COPY layouts/ /home/UserRepo/layouts/
COPY content/ /home/UserRepo/content/

WORKDIR /home/CentralRepo

# Overlay our custom layouts/shortcodes on top of the theme's
RUN cp -r /home/UserRepo/layouts/. /home/CentralRepo/layouts/ 2>/dev/null || true

# Generate config.toml from repoConfig.json, then build Hugo site at /docs
RUN ./scripts/generate_toml.sh && \
    hugo --minify --cleanDestinationDir \
         --contentDir /home/UserRepo/content \
         --baseURL /docs/

# --- Production stage ---
FROM nginx:alpine

# React SPA
COPY --from=react-build /app/dist /usr/share/nginx/html
# Hugo docs site
COPY --from=hugo-build /home/CentralRepo/public /usr/share/nginx/html/docs

COPY ui/frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost:3000/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
