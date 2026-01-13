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
    # Fix plugin paths if mounted from Mac host
    # Config files may contain Mac paths (/Users/...) that need to be
    # converted to container paths (/home/node/...)
    PLUGINS_DIR="$HOME/.claude/plugins"

    for config_file in "$PLUGINS_DIR/known_marketplaces.json" "$PLUGINS_DIR/installed_plugins.json"; do
        if [ -f "$config_file" ] && grep -q "/Users/" "$config_file" 2>/dev/null; then
            echo "  -> Fixing paths in $(basename "$config_file") for container..."
            sed -i "s|/Users/[^/]*/\.claude|$HOME/.claude|g" "$config_file"
        fi
    done

    # Add marketplace
    claude plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace 2>/dev/null || true

    # Install flow-next with user scope (global, not project-local)
    if ! grep -q '"scope": "user"' "$PLUGINS_DIR/installed_plugins.json" 2>/dev/null || \
       ! grep -q "flow-next" "$PLUGINS_DIR/installed_plugins.json" 2>/dev/null; then
        echo "  -> Installing flow-next plugin..."
        claude plugin install flow-next --scope user 2>/dev/null || {
            echo "  -> Could not auto-install flow-next via CLI"
            echo "     Run manually: /plugin install flow-next"
        }
    else
        echo "  -> flow-next plugin already installed"
    fi
else
    echo "  -> Claude CLI not available, skipping plugin install"
fi

# =============================================================================
# 3b. Pre-configure flow-next for immediate use
# =============================================================================
FLOW_DIR=".flow"
if [ ! -d "$FLOW_DIR" ]; then
    echo "  -> Initializing .flow/ directory..."
    mkdir -p "$FLOW_DIR/bin"

    # Create meta.json
    cat > "$FLOW_DIR/meta.json" << 'EOF'
{"schema_version": 2, "next_epic": 1}
EOF

    # Create config.json
    cat > "$FLOW_DIR/config.json" << 'EOF'
{"memory": {"enabled": false}}
EOF

    # Copy flowctl scripts if plugin is installed
    PLUGIN_SCRIPTS="$HOME/.claude/plugins/cache/gmickel-claude-marketplace/flow-next"
    LATEST_VERSION=$(ls -1 "$PLUGIN_SCRIPTS" 2>/dev/null | sort -V | tail -1)
    if [ -n "$LATEST_VERSION" ] && [ -d "$PLUGIN_SCRIPTS/$LATEST_VERSION/scripts" ]; then
        cp "$PLUGIN_SCRIPTS/$LATEST_VERSION/scripts/flowctl" "$FLOW_DIR/bin/flowctl" 2>/dev/null || true
        cp "$PLUGIN_SCRIPTS/$LATEST_VERSION/scripts/flowctl.py" "$FLOW_DIR/bin/flowctl.py" 2>/dev/null || true
        chmod +x "$FLOW_DIR/bin/flowctl" 2>/dev/null || true
        echo "  -> Copied flowctl to .flow/bin/"
    fi

    # Add flow-next instructions to CLAUDE.md
    CLAUDE_MD="CLAUDE.md"
    FLOW_NEXT_SNIPPET='<!-- BEGIN FLOW-NEXT -->
## Flow-Next

This project uses Flow-Next for task tracking. Use `.flow/bin/flowctl` instead of markdown TODOs or TodoWrite.

**Quick commands:**
```bash
.flow/bin/flowctl list                # List all epics + tasks
.flow/bin/flowctl epics               # List all epics
.flow/bin/flowctl tasks --epic fn-N   # List tasks for epic
.flow/bin/flowctl ready --epic fn-N   # What'\''s ready
.flow/bin/flowctl show fn-N.M         # View task
.flow/bin/flowctl start fn-N.M        # Claim task
.flow/bin/flowctl done fn-N.M --summary-file s.md --evidence-json e.json
```

**Rules:**
- Use `.flow/bin/flowctl` for ALL task tracking
- Do NOT create markdown TODOs or use TodoWrite
- Re-anchor (re-read spec + status) before every task

**More info:** `.flow/bin/flowctl --help` or read `.flow/usage.md`
<!-- END FLOW-NEXT -->'

    if [ -f "$CLAUDE_MD" ]; then
        if ! grep -q "BEGIN FLOW-NEXT" "$CLAUDE_MD" 2>/dev/null; then
            echo "" >> "$CLAUDE_MD"
            echo "$FLOW_NEXT_SNIPPET" >> "$CLAUDE_MD"
            echo "  -> Added flow-next instructions to CLAUDE.md"
        else
            echo "  -> CLAUDE.md already has flow-next instructions"
        fi
    else
        echo "$FLOW_NEXT_SNIPPET" > "$CLAUDE_MD"
        echo "  -> Created CLAUDE.md with flow-next instructions"
    fi

    echo "  -> flow-next fully configured"
else
    echo "  -> .flow/ directory already exists"
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
