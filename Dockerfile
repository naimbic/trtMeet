# trtMeet — custom Jitsi Meet web frontend.
# Multi-stage: build the frontend from source, then overlay it onto the
# official jitsi/web runtime so it stays compatible with the docker-jitsi-meet
# backend (prosody/jicofo/jvb) and keeps all its env-driven config templating.
#
# IMPORTANT: this image is a drop-in replacement for `jitsi/web:stable-10888`.
# It must run with the SAME environment + network as the existing web service
# (XMPP_DOMAIN, XMPP_BOSH_URL_BASE, PUBLIC_URL, etc.) or it cannot reach a backend.

# ---------- build stage ----------
FROM node:24-bookworm AS builder
WORKDIR /src
ENV NODE_OPTIONS=--max-old-space-size=8192
RUN apt-get update && apt-get install -y --no-install-recommends \
        git make python3 g++ ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Full source is needed before install (patch-package/postinstall run against it).
COPY . .
RUN npm ci
RUN make

# ---------- runtime stage ----------
FROM jitsi/web:stable-10888
# Overlay the custom-built frontend on top of the stock web root.
# COPY is additive/overwrite: image-only files (head.html, scripts, etc.) are kept.
COPY --from=builder /src/libs    /usr/share/jitsi-meet/libs
COPY --from=builder /src/css     /usr/share/jitsi-meet/css
COPY --from=builder /src/lang    /usr/share/jitsi-meet/lang
COPY --from=builder /src/sounds  /usr/share/jitsi-meet/sounds
COPY --from=builder /src/images  /usr/share/jitsi-meet/images
COPY --from=builder /src/fonts   /usr/share/jitsi-meet/fonts
COPY --from=builder /src/static  /usr/share/jitsi-meet/static
COPY --from=builder /src/*.html  /usr/share/jitsi-meet/
# Make the trtMeet branding stick: the runtime regenerates interface_config.js
# from this template on container start, so override the template itself.
COPY --from=builder /src/interface_config.js /defaults/interface_config.js
