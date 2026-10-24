#!/usr/bin/env bash
set -Eeuo pipefail

: "${VNC_USER:?Set VNC_USER in .env}"
: "${VNC_PASSWORD:?Set VNC_PASSWORD in .env}"

export DISPLAY="${DISPLAY:-:0}"
PROFILE_DIR="/config/chrome-profile"

# Volume-এর ownership ঠিক করা; SingletonLock permission error এড়াতে
mkdir -p /config
chown -R browser:browser /config

if [[ "${FRESH_PROFILE:-false}" == "true" ]]; then
    rm -rf "$PROFILE_DIR"
fi

mkdir -p "$PROFILE_DIR"
chown -R browser:browser "$PROFILE_DIR"

# Nginx Basic Auth credentials file তৈরি
printf '%s:%s\n' "$VNC_USER" "$(openssl passwd -apr1 "$VNC_PASSWORD")" \
    > /etc/nginx/.htpasswd
chmod 640 /etc/nginx/.htpasswd

# Virtual display
Xvfb "$DISPLAY" -screen 0 1280x800x24 -ac +extension GLX +render -noreset &
XVFB_PID=$!

for _ in $(seq 1 30); do
    if [[ -S /tmp/.X11-unix/X0 ]]; then
        break
    fi
    sleep 1
done

# Minimal window manager
su -s /bin/bash browser -c \
    "DISPLAY='$DISPLAY' openbox-session" &
OPENBOX_PID=$!

# VNC server; browser-এ localhost ছাড়া অন্য কোনো host-এ port প্রকাশ করা হয় না
x11vnc -display "$DISPLAY" \
    -forever \
    -shared \
    -nopw \
    -listen 127.0.0.1 \
    -rfbport 5900 &
X11VNC_PID=$!

# noVNC static files এবং WebSocket proxy
websockify --web=/usr/share/novnc 6080 127.0.0.1:5900 &
WEBSOCKIFY_PID=$!

nginx -g 'daemon off;' &
NGINX_PID=$!

# Chrome-কে browser user হিসেবে চালানো
su -s /bin/bash browser -c \
    "DISPLAY='$DISPLAY' /usr/local/bin/chrome-session" &
CHROME_PID=$!

cleanup() {
    kill "$CHROME_PID" "$NGINX_PID" "$WEBSOCKIFY_PID" \
         "$X11VNC_PID" "$OPENBOX_PID" "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

wait -n "$CHROME_PID" "$NGINX_PID" "$WEBSOCKIFY_PID" \
      "$X11VNC_PID" "$OPENBOX_PID" "$XVFB_PID"
