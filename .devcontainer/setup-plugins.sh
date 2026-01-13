#!/bin/bash
set -e

echo "======================================================================="
echo "  Setting up Claude Code plugins and MCP connections..."
echo "======================================================================="

REPOPROMPT_URL="${REPOPROMPT_MCP_URL:-http://host.docker.internal:8096/sse}"
CONFIG_FILE="$HOME/.claude.json"
SKILLS_DIR="$HOME/.claude/skills"

# =============================================================================
# 1. Configure Repo Prompt MCP
# =============================================================================
echo ""
echo "[1/4] Setting up Repo Prompt MCP..."

if command -v claude &> /dev/null; then
    claude mcp add RepoPrompt \
        --transport http \
        --scope user \
        "$REPOPROMPT_URL" 2>/dev/null || {
        echo "  -> Could not auto-configure RepoPrompt MCP via CLI"
    }
fi

# Write MCP config directly as fallback
if [ -f "$CONFIG_FILE" ]; then
    jq --arg url "$REPOPROMPT_URL" '.mcpServers.RepoPrompt = {
        "type": "http",
        "url": $url,
        "trusted": true,
        "autoStart": true
    }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
    cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "RepoPrompt": {
      "type": "http",
      "url": "$REPOPROMPT_URL",
      "trusted": true,
      "autoStart": true
    }
  }
}
EOF
fi

# Test Repo Prompt connection
if curl -s --max-time 3 "$REPOPROMPT_URL" > /dev/null 2>&1; then
    echo "  -> Repo Prompt MCP bridge is reachable"
else
    echo "  -> Repo Prompt MCP bridge not responding (start it on Mac)"
fi

# =============================================================================
# 2. Install dev-browser skill (SawyerHood)
# =============================================================================
echo ""
echo "[2/4] Setting up dev-browser skill..."

mkdir -p "$SKILLS_DIR"

if [ ! -d "$SKILLS_DIR/dev-browser" ]; then
    git clone --depth 1 https://github.com/SawyerHood/dev-browser.git /tmp/dev-browser-skill 2>/dev/null || {
        echo "  -> Could not clone dev-browser repository"
    }

    if [ -d "/tmp/dev-browser-skill/skills/dev-browser" ]; then
        cp -r /tmp/dev-browser-skill/skills/dev-browser "$SKILLS_DIR/dev-browser"
        rm -rf /tmp/dev-browser-skill

        # Install dependencies with bun
        cd "$SKILLS_DIR/dev-browser"
        if command -v bun &> /dev/null; then
            bun install 2>/dev/null || npm install 2>/dev/null || true
        else
            npm install 2>/dev/null || true
        fi
        cd - > /dev/null

        echo "  -> dev-browser skill installed"
    fi
else
    echo "  -> dev-browser skill already installed"
fi

# =============================================================================
# 3. Install flow-next plugin (Gordon Mickel)
# =============================================================================
echo ""
echo "[3/4] Setting up flow-next plugin..."

if command -v claude &> /dev/null; then
    # Add marketplace
    claude plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace 2>/dev/null || true

    # Install flow-next
    claude plugin install flow-next 2>/dev/null || {
        echo "  -> Could not auto-install flow-next via CLI"
        echo "     Run manually: /plugin install flow-next"
    }
else
    echo "  -> Claude CLI not available, skipping plugin install"
fi

# =============================================================================
# 4. Configure permissions
# =============================================================================
echo ""
echo "[4/4] Configuring permissions..."

SETTINGS_FILE="$HOME/.claude/settings.json"
if [ ! -f "$SETTINGS_FILE" ]; then
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "permissions": {
    "allow": [
      "Skill(dev-browser:dev-browser)",
      "Bash(npx tsx:*)",
      "Bash(bun:*)"
    ]
  }
}
EOF
    echo "  -> Created settings.json with dev-browser permissions"
else
    # Merge permissions
    jq '.permissions.allow += [
        "Skill(dev-browser:dev-browser)",
        "Bash(npx tsx:*)",
        "Bash(bun:*)"
    ] | .permissions.allow |= unique' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && \
    mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    echo "  -> Updated settings.json with dev-browser permissions"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "======================================================================="
echo "  Setup complete!"
echo "======================================================================="
echo ""
echo "  Installed:"
echo "    - Repo Prompt MCP ($REPOPROMPT_URL)"
echo "    - dev-browser skill"
echo "    - flow-next plugin"
echo ""
echo "  Start Claude Code with:"
echo "    claude --dangerously-skip-permissions"
echo ""
echo "  Commands:"
echo "    /flow-next:setup           # One-time flow-next setup"
echo "    /flow-next:plan <feature>  # Plan a feature"
echo "    /RepoPrompt:rp-build       # Build with Repo Prompt"
echo ""
echo "======================================================================="
