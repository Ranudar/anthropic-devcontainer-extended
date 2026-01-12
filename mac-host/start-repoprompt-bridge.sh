#!/bin/bash
# Start Repo Prompt MCP server exposed over SSE for devcontainers
set -e

REPO_PROMPT_CLI="$HOME/RepoPrompt/repoprompt_cli"
PORT=8096

# Verify CLI exists
if [ ! -f "$REPO_PROMPT_CLI" ]; then
    echo "❌ repoprompt_cli not found at $REPO_PROMPT_CLI"
    echo ""
    echo "   The CLI is installed when you first configure MCP in Repo Prompt:"
    echo "   1. Open Repo Prompt app"
    echo "   2. Check Settings/MCP for the CLI path"
    echo ""
    exit 1
fi

# Kill any existing instance
pkill -f "mcp-proxy.*$PORT" 2>/dev/null || true
sleep 1

echo "🚀 Starting Repo Prompt MCP bridge"
echo "   CLI: $REPO_PROMPT_CLI"
echo "   Port: $PORT"
echo "   Container URL: http://host.docker.internal:$PORT/sse"
echo ""
echo "   Press Ctrl+C to stop"
echo ""

# Start mcp-proxy in SSE-to-stdio mode
exec mcp-proxy \
    --host 0.0.0.0 \
    --port $PORT \
    --pass-environment \
    "$REPO_PROMPT_CLI"
