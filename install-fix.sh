#!/bin/bash

# Windsurf Cascade Fix Installer
# Automatically fixes the "warming up" issue in Coder workspaces

set -e

echo "╔════════════════════════════════════════════╗"
echo "║   Windsurf Cascade Fix Installer v1.0     ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Check if fix is already running
echo "→ Checking existing proxy..."
if pgrep -f windsurf-proxy.py > /dev/null; then
    echo -e "${YELLOW}⚠ Proxy already running. Restarting...${NC}"
    pkill -f windsurf-proxy.py
    sleep 2
fi

# Step 2: Check Python availability
echo "→ Verifying Python..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python 3 is required but not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python 3 found${NC}"

# Step 3: Check if Windsurf is running
echo "→ Checking Windsurf processes..."
if ! pgrep -f language_server > /dev/null; then
    echo -e "${YELLOW}⚠ Windsurf language server not detected${NC}"
    echo "  Please ensure Windsurf is running and try again"
    # Don't exit - proxy can start anyway
fi

# Step 4: Install proxy script
echo "→ Installing proxy script..."
cp windsurf-proxy.py ~/windsurf-proxy.py
chmod +x ~/windsurf-proxy.py
echo -e "${GREEN}✓ Proxy script installed${NC}"

# Step 5: Start the proxy
echo "→ Starting proxy service..."
nohup python3 ~/windsurf-proxy.py > ~/windsurf-proxy.log 2>&1 &
PROXY_PID=$!
sleep 2

# Step 6: Verify proxy is running
if kill -0 $PROXY_PID 2>/dev/null; then
    echo -e "${GREEN}✓ Proxy started successfully (PID: $PROXY_PID)${NC}"
else
    echo -e "${RED}✗ Failed to start proxy${NC}"
    echo "  Check ~/windsurf-proxy.log for errors"
    exit 1
fi

# Step 7: Verify ports are listening
echo "→ Verifying port bindings..."
PORTS_OK=true
if ! netstat -tulpn 2>/dev/null | grep -q ":51801"; then
    echo -e "${RED}✗ Port 51801 not listening${NC}"
    PORTS_OK=false
fi
if ! netstat -tulpn 2>/dev/null | grep -q ":48359"; then
    echo -e "${RED}✗ Port 48359 not listening${NC}"
    PORTS_OK=false
fi

if [ "$PORTS_OK" = true ]; then
    echo -e "${GREEN}✓ All ports are listening${NC}"
fi

# Step 8: Add to bashrc for persistence
echo "→ Making fix permanent..."
if ! grep -q "windsurf-proxy.py" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# Auto-start Windsurf proxy fix
if ! pgrep -f windsurf-proxy.py > /dev/null 2>&1; then
    nohup python3 ~/windsurf-proxy.py > ~/windsurf-proxy.log 2>&1 &
fi
EOF
    echo -e "${GREEN}✓ Added to ~/.bashrc for auto-start${NC}"
else
    echo -e "${YELLOW}⚠ Already in ~/.bashrc${NC}"
fi

# Step 9: Final status
echo ""
echo "╔════════════════════════════════════════════╗"
echo "║            Installation Complete!          ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "Port Mapping:"
echo "  • Server:  localhost:41801 → 0.0.0.0:51801"
echo "  • LSP:     localhost:38359 → 0.0.0.0:48359"
echo ""
echo "Next Steps:"
echo "  1. Reload your Windsurf window"
echo "  2. Cascade should now load properly"
echo ""
echo "Logs available at: ~/windsurf-proxy.log"
echo ""
echo -e "${GREEN}✨ Fix successfully applied!${NC}"