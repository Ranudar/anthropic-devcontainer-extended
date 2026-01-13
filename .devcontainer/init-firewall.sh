#!/bin/bash
set -e

echo "🔒 Initializing firewall rules..."

# Create ipset for allowed IPs
ipset create allowed_ips hash:net -exist

# Allowed domains (from Anthropic reference + additions for MCP + plugins)
ALLOWED_DOMAINS=(
    # Anthropic
    "api.anthropic.com"
    "statsig.anthropic.com"
    "sentry.io"
    
    # Package registries
    "registry.npmjs.org"
    "npmjs.org"
    "github.com"
    "api.github.com"
    "objects.githubusercontent.com"
    "raw.githubusercontent.com"
    "codeload.github.com"
    
    # VS Code
    "update.code.visualstudio.com"
    "marketplace.visualstudio.com"
    "vscode.blob.core.windows.net"
    
    # PyPI for mcp-proxy updates
    "pypi.org"
    "files.pythonhosted.org"
    
    # Bun registry
    "bun.sh"
    "registry.npmmirror.com"
    
    # Playwright browser downloads
    "playwright.azureedge.net"
    "playwright-akamai.azureedge.net"
    "playwright-verizon.azureedge.net"
)

# Resolve domains and add to ipset
for domain in "${ALLOWED_DOMAINS[@]}"; do
    ips=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
    for ip in $ips; do
        ipset add allowed_ips "$ip" -exist 2>/dev/null || true
    done
done

# Allow localhost (for internal services)
ipset add allowed_ips 127.0.0.0/8 -exist

# Allow Docker host (for Repo Prompt MCP bridge)
# Filter for IPv4 only (ipset hash:net defaults to IPv4)
HOST_IP=$(getent ahostsv4 host.docker.internal 2>/dev/null | awk '{ print $1 }' | head -1 || echo "")
if [ -z "$HOST_IP" ]; then
    # Fallback to default Docker bridge
    HOST_IP="172.17.0.1"
fi
ipset add allowed_ips "$HOST_IP" -exist
echo "✅ Added Docker host ($HOST_IP) to allowed IPs for MCP bridge"

# Allow Docker network ranges
ipset add allowed_ips 172.16.0.0/12 -exist
ipset add allowed_ips 192.168.0.0/16 -exist

# Set default policy
iptables -P OUTPUT DROP

# Allow established connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Allow DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTPS to approved destinations
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed_ips dst -j ACCEPT

# Allow HTTP to approved destinations (some registries use HTTP)
iptables -A OUTPUT -p tcp --dport 80 -m set --match-set allowed_ips dst -j ACCEPT

# Allow MCP bridge port (8096) to Docker host
iptables -A OUTPUT -p tcp --dport 8096 -d "$HOST_IP" -j ACCEPT

# Allow dev-browser server port (default 3333)
iptables -A OUTPUT -p tcp --dport 3333 -j ACCEPT

# Allow common dev server ports for localhost testing
for port in 3000 3001 4000 5000 5173 8000 8080; do
    iptables -A OUTPUT -p tcp --dport $port -d 127.0.0.1 -j ACCEPT
done

echo "✅ Firewall rules initialized"
echo "   - Allowed ${#ALLOWED_DOMAINS[@]} domains"
echo "   - Docker host: $HOST_IP"
echo "   - MCP bridge port: 8096"
