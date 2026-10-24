#!/usr/bin/env bash
set -euo pipefail

: "${VNC_USER:?Set VNC_USER in .env}"
: "${VNC_PASSWORD:?Set VNC_PASSWORD in .env}"

mkdir -p /run/nginx /config/chrome-profile
htpasswd -bc /run/nginx/.htpasswd "$VNC_USER" "$VNC_PASSWORD"

# VNC desktop is only reachable locally; browser access goes through
# nginx authentication on port 3000.
runuser -u browser -- tigervncserver :1 \
  -geometry 1600x900 \
  -depth 24 \
  -localhost yes \
  -SecurityTypes None \
  -xstartup /usr/bin/startxfce4

websockify --web=/usr/share/novnc 127.0.0.1:6080 127.0.0.1:5901 &
nginx -g 'daemon off;' &
NGINX_PID=$!

sleep 2

runuser -u browser -- \
  google-chrome-stable \
  --user-data-dir=/config/chrome-profile \
  --no-first-run \
  --no-default-browser-check \
  >/tmp/chrome.log 2>&1 &

wait "$NGINX_PID"
