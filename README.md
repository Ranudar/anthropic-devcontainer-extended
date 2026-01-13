# Claude Code Extended Devcontainer

A layered devcontainer for Claude Code with browser automation, workflow tooling, and Python/Node development.

## Features

| Component | Purpose |
|-----------|---------|
| **Claude Code CLI** | Anthropic's AI coding assistant |
| **Repo Prompt MCP** | Context building via Mac host bridge |
| **dev-browser** | Browser automation skill (SawyerHood) |
| **flow-next** | Planning/execution workflow (Gordon Mickel) |
| **Playwright** | E2E testing (pytest-playwright) |
| **Python 3.14 + uv** | Python development |
| **Node 20 + Bun** | JavaScript/TypeScript development |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: mcr.microsoft.com/playwright:v1.57.0-noble                     │
│ Ubuntu 24.04 · Node 20 · Chromium · Firefox · WebKit                    │
├─────────────────────────────────────────────────────────────────────────┤
│ LAYER 2: Anthropic Claude Code essentials                               │
│ Claude Code CLI · iptables/ipset · firewall script                      │
├─────────────────────────────────────────────────────────────────────────┤
│ LAYER 3: Common dev tools                                               │
│ zsh · fzf · git-delta · gh · jq · ripgrep · fd                          │
│ Python 3.14 (via uv) · ruff · Bun                                       │
├─────────────────────────────────────────────────────────────────────────┤
│ LAYER 4: postCreateCommand (always fresh)                               │
│ flow-next · dev-browser · Repo Prompt MCP config                        │
└─────────────────────────────────────────────────────────────────────────┘

        ▲
        │ MCP bridge (port 8096)
        ▼

┌─────────────────────────────────────────────────────────────────────────┐
│ MAC HOST                                                                │
│ mcp-proxy :8096 ◄── ~/RepoPrompt/repoprompt_cli                         │
└─────────────────────────────────────────────────────────────────────────┘
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

## Testing the Devcontainer

After opening the container, run these tests to verify all components work:

### 1. Test Base Tools

```bash
# Check versions
node --version          # Should show v20.x
python3.14 --version    # Should show Python 3.14.x
uv --version            # Should show uv 0.x
ruff --version          # Should show ruff 0.x
bun --version           # Should show bun 1.x
playwright --version    # Should show Version 1.57.x

# Check shell
echo $SHELL             # Should show /bin/zsh
```

### 2. Test Repo Prompt MCP (requires bridge on Mac)

```bash
# First, ensure the bridge is running on Mac:
# ~/bin/start-repoprompt-bridge.sh

# Test SSE endpoint (legacy transport)
curl -s http://host.docker.internal:8096/sse | head -1
# Should show: event: endpoint

# Test Streamable HTTP endpoint (preferred)
curl -s -X POST http://host.docker.internal:8096/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
# Should return JSON with serverInfo.name: "Repo Prompt"

# In Claude Code, verify MCP is connected
/mcp
# Should list RepoPrompt as connected
```

**MCP Transport Endpoints:**
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/mcp` | POST | Streamable HTTP transport (preferred) |
| `/sse` | GET | SSE event stream (returns session endpoint) |
| `/messages/?session_id=...` | POST | Send messages via SSE transport |

> **Note:** `POST /sse` returns 405 Method Not Allowed - this is expected. Use `/mcp` for Streamable HTTP or follow the SSE protocol (GET `/sse` → POST to returned endpoint).

### 3. Test flow-next Plugin

```bash
# In Claude Code terminal
claude --dangerously-skip-permissions

# Run setup (first time only)
/flow-next:setup

# Test planning (creates .flow/ directory)
/flow-next:plan Create a hello world script

# Verify .flow/ was created
ls -la .flow/
```

### 4. Test dev-browser Skill

```bash
# Start a simple test server
echo '<html><body><h1>Test Page</h1><button id="btn">Click me</button></body></html>' > /tmp/test.html
cd /tmp && python3.14 -m http.server 8080 &

# In Claude Code, ask to test it:
"Use dev-browser to check if localhost:8080 has a button with id 'btn'"

# Clean up
pkill -f "python3.14 -m http.server"
```

### 5. Test Playwright (E2E)

```bash
# Create a simple test
mkdir -p /tmp/playwright-test && cd /tmp/playwright-test

cat > test_example.py << 'EOF'
from playwright.sync_api import sync_playwright

def test_playwright_works():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto("https://example.com")
        assert "Example Domain" in page.title()
        browser.close()
        print("Playwright test passed!")

if __name__ == "__main__":
    test_playwright_works()
EOF

# Run with Python directly
python3.14 test_example.py

# Or with pytest (if in a project with pytest-playwright)
# pytest test_example.py -v
```

### 6. Test Firewall

```bash
# Should work (allowed domains)
curl -s https://api.anthropic.com -o /dev/null && echo "Anthropic API: OK"
curl -s https://registry.npmjs.org -o /dev/null && echo "npm registry: OK"

# Should fail (blocked)
curl -s --max-time 3 https://example.com || echo "example.com: Blocked (expected)"
```

### Quick Verification Checklist

| Component | Test Command | Expected Result |
|-----------|--------------|-----------------|
| Node.js | `node --version` | v20.x |
| Python | `python3.14 --version` | 3.14.x |
| uv | `uv --version` | 0.x |
| Bun | `bun --version` | 1.x |
| Playwright | `playwright --version` | 1.57.x |
| MCP Bridge (SSE) | `curl http://host.docker.internal:8096/sse` | `event: endpoint` |
| MCP Bridge (HTTP) | `curl -X POST http://host.docker.internal:8096/mcp -H "Content-Type: application/json" -H "Accept: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'` | `"name":"Repo Prompt"` |
| Firewall | `curl https://api.anthropic.com` | Success |

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

### Repo Prompt

```bash
/RepoPrompt:rp-build Add user authentication
/RepoPrompt:rp-investigate Why is checkout failing?
```

### E2E Tests (pytest-playwright)

```bash
# Run E2E tests
pytest tests/e2e/

# Run with headed browser
pytest tests/e2e/ --headed
```

---

## Files

| File | Description |
|------|-------------|
| `Dockerfile` | 4-layer build: Playwright → Claude Code → Dev tools |
| `devcontainer.json` | Mounts, env vars, VS Code extensions, postCreateCommand |
| `init-firewall.sh` | Whitelists domains, opens MCP port 8096 |
| `setup-plugins.sh` | Installs dev-browser, flow-next, configures MCP |

---

## Layer Details

### Layer 1: Playwright Base
- `mcr.microsoft.com/playwright:v1.57.0-noble`
- Pre-built browsers (Chromium, Firefox, WebKit)
- Node 20, npm
- Ubuntu 24.04 LTS

### Layer 2: Claude Code Essentials
- `@anthropic-ai/claude-code` CLI
- Firewall tools (iptables, ipset, iproute2, dnsutils)
- Sudoers config for firewall script

### Layer 3: Dev Tools
- **Shell:** zsh, oh-my-zsh, powerlevel10k, fzf
- **Git:** git-delta, gh
- **CLI:** jq, ripgrep, fd, unzip
- **Python:** uv, Python 3.14, ruff
- **JS:** Bun (for dev-browser)

### Layer 4: Dynamic Plugins (postCreateCommand)
Installed fresh on every container start:
- flow-next (Gordon Mickel's marketplace)
- dev-browser (SawyerHood)
- Repo Prompt MCP configuration

---

## Troubleshooting

**Repo Prompt not connecting:**
```bash
# Test SSE endpoint
curl http://host.docker.internal:8096/sse

# Test Streamable HTTP endpoint (preferred)
curl -X POST http://host.docker.internal:8096/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'

# Mac - ensure bridge running
~/bin/start-repoprompt-bridge.sh
```

**POST /sse returns 405 Method Not Allowed:**
This is expected. The `/sse` endpoint only accepts GET requests. Use `/mcp` for Streamable HTTP transport instead.

**flow-next not found:**
```bash
/plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace
/plugin install flow-next
/flow-next:setup
```

**dev-browser not working:**
```bash
cd ~/.claude/skills/dev-browser
bun install && bun run start-server
```

**Python version:**
```bash
# Check Python version
uv python list

# Use Python 3.14 in project
uv venv --python 3.14
uv sync
```

---

## Credits

- [Microsoft Playwright](https://playwright.dev/) - Base image & browser automation
- [Anthropic](https://github.com/anthropics/claude-code) - Claude Code CLI
- [SawyerHood](https://github.com/SawyerHood/dev-browser) - dev-browser skill
- [Gordon Mickel](https://github.com/gmickel/gmickel-claude-marketplace) - flow-next plugin
- [Astral](https://github.com/astral-sh/uv) - uv package manager
