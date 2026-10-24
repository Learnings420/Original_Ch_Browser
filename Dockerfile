FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    nginx \
    apache2-utils \
    xvfb \
    openbox \
    x11vnc \
    novnc \
    websockify \
    python3-xdg \
    dbus-x11 \
    xterm \
    fonts-liberation \
    fonts-noto-color-emoji \
    sudo \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Google signing key fingerprint যাচাই করে official Chrome APT repository যোগ করা
RUN set -eux; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub -o /tmp/google-linux-signing-key.pub; \
    ACTUAL_FINGERPRINT="$(gpg --show-keys --with-colons /tmp/google-linux-signing-key.pub \
      | awk -F: '$1 == "fpr" { print toupper($10); exit }')"; \
    EXPECTED_FINGERPRINT="EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796"; \
    
    test "$ACTUAL_FINGERPRINT" = "$EXPECTED_FINGERPRINT"; \
    gpg --dearmor < /tmp/google-linux-signing-key.pub \
      > /etc/apt/keyrings/google-linux-signing-key.gpg; \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-linux-signing-key.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends google-chrome-stable; \
    rm -rf /var/lib/apt/lists/* /tmp/google-linux-signing-key.pub

RUN useradd --create-home --shell /bin/bash browser \
    && mkdir -p /config /tmp/chromium-config \
    && chown -R browser:browser /home/browser /config /tmp/chromium-config

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /usr/local/bin/start.sh
COPY chrome-session /usr/local/bin/chrome-session

RUN chmod +x /usr/local/bin/start.sh /usr/local/bin/chrome-session

EXPOSE 3000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start.sh"]
