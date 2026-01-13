# =============================================================================
# Claude Code Extended Devcontainer
# 4-layer architecture for fast rebuilds
# =============================================================================

# =============================================================================
# LAYER 1: Playwright base image
# Pre-built browsers (Chromium, Firefox, WebKit) + Node 20 + Ubuntu 24.04
# =============================================================================
FROM mcr.microsoft.com/playwright:v1.57.0-noble

# =============================================================================
# LAYER 2: Anthropic Claude Code essentials
# =============================================================================

# Firewall tools + basic utilities + locale
RUN apt-get update && apt-get install -y --no-install-recommends \
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    sudo \
    curl \
    wget \
    locales \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && sed -i '/en_DK.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Locale: English messages + ISO dates (YYYY-MM-DD) + 24h time
ENV LANG=en_US.UTF-8
ENV LC_TIME=en_DK.UTF-8

# Create node user (Playwright image uses pwuser, we want node for Anthropic compatibility)
ARG USERNAME=node
RUN useradd -m -s /bin/bash $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code@latest

# Firewall script and sudoers
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh && \
    echo "$USERNAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
    chmod 0440 /etc/sudoers.d/node-firewall

# =============================================================================
# LAYER 3: Common dev tools
# =============================================================================

# Shell and CLI tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh \
    fzf \
    jq \
    ripgrep \
    fd-find \
    gh \
    unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# git-delta (better diffs)
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
    wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Create directories for node user
RUN mkdir -p /home/$USERNAME/.claude/plugins \
             /home/$USERNAME/.claude/skills \
             /home/$USERNAME/.local/bin \
             /commandhistory && \
    touch /commandhistory/.bash_history && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME /commandhistory

# Switch to node user for remaining installs
USER $USERNAME
WORKDIR /home/$USERNAME

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Install Python 3.14 via uv
RUN uv python install 3.14

# Install ruff globally via uv
RUN uv tool install ruff

# Install Bun (for dev-browser)
RUN curl -fsSL https://bun.sh/install | bash
ENV BUN_INSTALL="/home/$USERNAME/.bun"
ENV PATH="/home/$USERNAME/.bun/bin:$PATH"

# Configure zsh
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -a 'export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"' \
    -a 'export HISTFILE=/commandhistory/.bash_history' \
    -x

# =============================================================================
# LAYER 4: Dynamic plugins (handled by postCreateCommand)
# See setup-plugins.sh for: flow-next, dev-browser, Repo Prompt MCP config
# =============================================================================

# Copy setup script
USER root
COPY setup-plugins.sh /usr/local/bin/setup-plugins.sh
RUN chmod +x /usr/local/bin/setup-plugins.sh

# Environment
ENV SHELL=/bin/zsh
ENV EDITOR=nano
ENV VISUAL=nano
ENV DEVCONTAINER=true
ENV UV_PYTHON_PREFERENCE=managed

USER $USERNAME
WORKDIR /workspaces
