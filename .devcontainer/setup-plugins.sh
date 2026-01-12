#!/bin/bash
set -e

echo "🔗 Configuring Claude Code plugins and MCP connections..."

REPOPROMPT_URL="${REPOPROMPT_MCP_URL:-http://host.docker.internal:8096/sse}"
CONFIG_FILE="$HOME/.claude.json"
PLUGINS_DIR="$HOME/.claude/plugins"
SKILLS_DIR="$HOME/.claude/skills"

# Wait for Claude Code to be available
sleep 2

# =============================================================================
# 1. Configure Repo Prompt MCP
# =============================================================================
echo ""
echo "📦 Setting up Repo Prompt MCP..."

if command -v claude &> /dev/null; then
    claude mcp add RepoPrompt \
        --transport http \
        --scope user \
        "$REPOPROMPT_URL" 2>/dev/null || {
        echo "⚠️  Could not auto-configure RepoPrompt MCP via CLI"
    }
fi

# Write MCP config directly
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
echo "🔍 Testing Repo Prompt MCP bridge connection..."
if curl -s --max-time 5 "$REPOPROMPT_URL" > /dev/null 2>&1; then
    echo "✅ Repo Prompt MCP bridge is reachable at $REPOPROMPT_URL"
else
    echo ""
    echo "⚠️  Repo Prompt MCP bridge not responding at $REPOPROMPT_URL"
    echo "   Please start the bridge on your Mac:"
    echo "   ~/bin/start-repoprompt-bridge.sh"
fi

# =============================================================================
# 2. Install dev-browser plugin (SawyerHood)
# =============================================================================
echo ""
echo "🌐 Setting up dev-browser plugin..."

mkdir -p "$SKILLS_DIR"

# Clone dev-browser and install
if [ ! -d "$SKILLS_DIR/dev-browser" ]; then
    git clone --depth 1 https://github.com/SawyerHood/dev-browser.git /tmp/dev-browser-skill 2>/dev/null || {
        echo "⚠️  Could not clone dev-browser repository"
    }
    
    if [ -d "/tmp/dev-browser-skill/skills/dev-browser" ]; then
        cp -r /tmp/dev-browser-skill/skills/dev-browser "$SKILLS_DIR/dev-browser"
        rm -rf /tmp/dev-browser-skill
        
        # Install dependencies
        cd "$SKILLS_DIR/dev-browser"
        if command -v bun &> /dev/null; then
            bun install 2>/dev/null || npm install 2>/dev/null || true
        else
            npm install 2>/dev/null || true
        fi
        
        echo "✅ dev-browser skill installed"
    fi
else
    echo "✅ dev-browser skill already installed"
fi

# =============================================================================
# 3. Add Gordon Mickel's marketplace and install flow-next
# =============================================================================
echo ""
echo "🔄 Setting up flow-next plugin (Gordon Mickel)..."

# Add marketplace and install flow-next via Claude Code CLI if available
if command -v claude &> /dev/null; then
    # Try to add marketplace and install flow-next
    # Note: These commands may require interactive auth, so we provide fallback
    echo "   Adding gmickel marketplace..."
    claude plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace 2>/dev/null || true
    
    echo "   Installing flow-next..."
    claude plugin install flow-next 2>/dev/null || {
        echo "⚠️  Could not auto-install flow-next via CLI"
        echo "   Run manually in Claude Code:"
        echo "   /plugin marketplace add https://github.com/gmickel/gmickel-claude-marketplace"
        echo "   /plugin install flow-next"
    }
fi

# Also clone the marketplace for manual access
if [ ! -d "$PLUGINS_DIR/marketplaces/gmickel-claude-marketplace" ]; then
    mkdir -p "$PLUGINS_DIR/marketplaces"
    git clone --depth 1 https://github.com/gmickel/gmickel-claude-marketplace.git \
        "$PLUGINS_DIR/marketplaces/gmickel-claude-marketplace" 2>/dev/null || {
        echo "⚠️  Could not clone gmickel marketplace"
    }
    
    if [ -d "$PLUGINS_DIR/marketplaces/gmickel-claude-marketplace" ]; then
        echo "✅ gmickel-claude-marketplace cloned"
    fi
fi

# =============================================================================
# 4. Configure Playwright MCP (optional, for direct Playwright control)
# =============================================================================
echo ""
echo "🎭 Setting up Playwright MCP..."

if command -v claude &> /dev/null; then
    claude mcp add playwright -- npx @playwright/mcp@latest 2>/dev/null || {
        echo "⚠️  Could not auto-configure Playwright MCP"
    }
fi

# Update config with Playwright MCP
if [ -f "$CONFIG_FILE" ]; then
    jq '.mcpServers.playwright = {
        "type": "stdio",
        "command": "npx",
        "args": ["@playwright/mcp@latest"],
        "trusted": true
    }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi

echo "✅ Playwright MCP configured"

# =============================================================================
# 5. Set up permissions for dev-browser
# =============================================================================
echo ""
echo "🔑 Configuring permissions..."

# Create or update settings.json for skill permissions
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ ! -f "$SETTINGS_FILE" ]; then
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "permissions": {
    "allow": [
      "Skill(dev-browser:dev-browser)",
      "Bash(npx tsx:*)",
      "Bash(bun:*)",
      "Bash(npx @playwright/mcp:*)"
    ]
  }
}
EOF
    echo "✅ Created settings.json with dev-browser permissions"
else
    # Merge permissions
    jq '.permissions.allow += [
        "Skill(dev-browser:dev-browser)",
        "Bash(npx tsx:*)",
        "Bash(bun:*)",
        "Bash(npx @playwright/mcp:*)"
    ] | .permissions.allow |= unique' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && \
    mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    echo "✅ Updated settings.json with dev-browser permissions"
fi

# =============================================================================
# 6. Print summary
# =============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "🎉 Setup complete!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📋 Installed components:"
echo "   ✓ Repo Prompt MCP (http://host.docker.internal:8096/sse)"
echo "   ✓ dev-browser skill (SawyerHood)"
echo "   ✓ flow-next plugin (Gordon Mickel)"
echo "   ✓ Playwright MCP"
echo ""
echo "🚀 Start Claude Code with:"
echo "   claude --dangerously-skip-permissions"
echo ""
echo "📖 Available commands:"
echo ""
echo "   Repo Prompt MCP:"
echo "   /RepoPrompt:rp-build <task>"
echo "   /RepoPrompt:rp-investigate <issue>"
echo ""
echo "   flow-next (run setup first):"
echo "   /flow-next:setup"
echo "   /flow-next:plan <feature description>"
echo "   /flow-next:work fn-1"
echo ""
echo "   dev-browser:"
echo "   Just ask Claude to 'test the signup flow' or 'verify the form works'"
echo ""
echo "   Playwright MCP:"
echo "   'Use playwright to open localhost:3000'"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
