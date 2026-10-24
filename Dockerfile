FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg \
    xfce4 dbus-x11 \
    tigervnc-standalone-server tigervnc-tools \
    novnc python3-websockify \
    nginx apache2-utils \
    && rm -rf /var/lib/apt/lists/*

# Google signing key download, fingerprint verification, and Chrome repository setup
RUN set -eux; \
    mkdir -p /usr/share/keyrings; \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub -o /tmp/google-chrome-key.pub; \
    gpg --show-keys --with-colons /tmp/google-chrome-key.pub \
      | awk -F: '$1 == "fpr" { print $10 }' \
      | grep -Fx "EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796"; \
    gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg /tmp/google-chrome-key.pub; \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends google-chrome-stable; \
    rm -rf /var/lib/apt/lists/* /tmp/google-chrome-key.pub

RUN useradd -m -s /bin/bash browser \
    && mkdir -p /config /run/nginx \
    && chown -R browser:browser /config

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3000

CMD ["/start.sh"]
