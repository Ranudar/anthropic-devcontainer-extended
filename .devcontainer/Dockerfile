# =============================================================================
# Extends the official Anthropic devcontainer base image
# https://github.com/anthropics/devcontainer-templates
# =============================================================================
FROM ghcr.io/anthropics/devcontainer-templates:latest AS anthropic-base


# =============================================================================
# Extension layer (dev-browser + flow-next + Playwright)
# =============================================================================
FROM anthropic-base AS extended

ARG USERNAME=node

# Playwright browser dependencies
RUN apt-get update && apt-get install -y \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgtk-3-0 \
    libx11-xcb1 \
    libxcb-dri3-0 \
    libxshmfence1 \
    xvfb \
    x11-utils \
    && rm -rf /var/lib/apt/lists/*

# Bun runtime (required for dev-browser)
USER $USERNAME
RUN curl -fsSL https://bun.sh/install | bash
ENV BUN_INSTALL="/home/${USERNAME}/.bun"
ENV PATH="/home/${USERNAME}/.bun/bin:${PATH}"

USER root

# Playwright + Chromium
RUN npm install -g playwright && \
    npx playwright install chromium --with-deps

# Plugin/skill directories
RUN mkdir -p /home/$USERNAME/.claude/plugins \
             /home/$USERNAME/.claude/skills \
             /home/$USERNAME/.cache/ms-playwright && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.claude /home/$USERNAME/.cache

# Extension scripts
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY setup-plugins.sh /usr/local/bin/setup-plugins.sh
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/setup-plugins.sh

ENV PLAYWRIGHT_BROWSERS_PATH=/home/${USERNAME}/.cache/ms-playwright

USER $USERNAME
WORKDIR /workspaces
