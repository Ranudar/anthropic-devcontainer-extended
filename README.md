# Claude Code Extended Devcontainer

Extends `ghcr.io/anthropics/devcontainer-templates` with browser automation and workflow tooling.

## What's Added

| Component | Purpose |
|-----------|---------|
| **Repo Prompt MCP** | Context building via Mac host bridge |
| **dev-browser** | Browser automation skill (SawyerHood) |
| **flow-next** | Planning/execution workflow (Gordon Mickel) |
| **Playwright + Chromium** | Browser engine + MCP |
| **Bun** | Runtime for dev-browser |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ MAC HOST                                                        │
│                                                                 │
│   mcp-proxy :8096 ◄── ~/RepoPrompt/repoprompt_cli              │
│        │                                                        │
└────────│────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────────┐
│ DEVCONTAINER                                                    │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ ghcr.io/anthropics/devcontainer-templates:latest           │ │
│  │ Claude Code · mcp-proxy · zsh · git-delta · fzf · gh       │ │
│  └────────────────────────────────────────────────────────────┘ │
│                          ▲ extends                              │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Extension Layer                                            │ │
│  │ Bun · Playwright · Chromium · Xvfb                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  MCP: RepoPrompt (host:8096) · Playwright                       │
│  Skills: dev-browser · flow-next                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Setup

### 1. Copy `.devcontainer/` to your project

```
.devcontainer/
├── devcontainer.json
├── Dockerfile
├── init-firewall.sh
└── setup-plugins.sh
```

### 2. Start Repo Prompt bridge on Mac

```bash
# Install
uv tool install mcp-proxy  # or: pipx install mcp-proxy

# Copy script
mkdir -p ~/bin
cp mac-host/start-repoprompt-bridge.sh ~/bin/
chmod +x ~/bin/start-repoprompt-bridge.sh

# Run (keep open)
~/bin/start-repoprompt-bridge.sh
```

Optional: manage the bridge with a LaunchAgent (manual start/stop, no auto-run on login):

```bash
# Install agent (does not start yet)
cp mac-host/com.repoprompt.mcp-bridge.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.repoprompt.mcp-bridge.plist

# Start when needed (e.g., before opening the devcontainer)
launchctl kickstart -k gui/$(id -u)/com.repoprompt.mcp-bridge

# Stop when done (stays stopped)
launchctl stop gui/$(id -u)/com.repoprompt.mcp-bridge

# Uninstall
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.repoprompt.mcp-bridge.plist
rm ~/Library/LaunchAgents/com.repoprompt.mcp-bridge.plist
```

### 3. Open in VS Code

Command Palette → **Reopen in Container**

### 4. Initialize plugins

```bash
claude --dangerously-skip-permissions

/mcp                    # Verify connections
/flow-next:setup        # One-time setup
```

---

## Usage

### flow-next

```bash
/flow-next:plan Add OAuth login     # Creates .flow/ with tasks
/flow-next:work fn-1                # Execute task
/flow-next:interview fn-1           # Refine spec with 40+ questions
```

### dev-browser

Just ask naturally:

```
"Test the signup flow on localhost:3000"
"Check why the save button isn't working"
"Verify form validation"
```

### Playwright MCP

```
"Use playwright to screenshot the dashboard"
"Fill out the contact form at localhost:3000/contact"
```

### Repo Prompt

```bash
/RepoPrompt:rp-build Add user authentication
/RepoPrompt:rp-investigate Why is checkout failing?
```

---

## Files

| File | Description |
|------|-------------|
| `Dockerfile` | 67 lines. Extends Anthropic base, adds Bun + Playwright |
| `devcontainer.json` | Mounts, env vars, VS Code extensions |
| `init-firewall.sh` | Whitelists domains, opens MCP port 8096 |
| `setup-plugins.sh` | Installs dev-browser, flow-next, configures MCP |

---

## Troubleshooting

**Repo Prompt not connecting:**
```bash
# Container
curl http://host.docker.internal:8096/sse

# Mac - ensure bridge running
~/bin/start-repoprompt-bridge.sh
```

**flow-next not found:**
```bash
/plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace
/plugin install flow-next
/flow-next:setup
```

**Playwright missing browsers:**
```bash
npx playwright install chromium --with-deps
```

**dev-browser not working:**
```bash
cd ~/.claude/skills/dev-browser
bun install && bun run start-server
```

---

## Credits

- [Anthropic](https://github.com/anthropics/devcontainer-templates) - Base image
- [SawyerHood](https://github.com/SawyerHood/dev-browser) - dev-browser
- [Gordon Mickel](https://github.com/gmickel/gmickel-claude-marketplace) - flow-next
- [Microsoft](https://github.com/microsoft/playwright-mcp) - Playwright MCP
