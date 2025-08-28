#!/bin/bash

# Windsurf Cascade Diagnostics Tool
# Collects comprehensive debugging information

echo "╔══════════════════════════════════════════════════════╗"
echo "║        Windsurf Cascade Diagnostics v1.0            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Collecting diagnostic information..."
echo ""

# Create temp file for report
REPORT="/tmp/windsurf-diagnostics-$(date +%Y%m%d-%H%M%S).txt"

{
    echo "WINDSURF CASCADE DIAGNOSTIC REPORT"
    echo "Generated: $(date)"
    echo "=================================="
    echo ""
    
    echo "SYSTEM INFORMATION"
    echo "------------------"
    echo "Hostname: $(hostname)"
    echo "Container IP: $(hostname -I)"
    echo "Kernel: $(uname -r)"
    echo "Python: $(python3 --version 2>&1)"
    echo ""
    
    echo "ENVIRONMENT VARIABLES"
    echo "--------------------"
    env | grep -E "CODER|WINDSURF" | sort
    echo ""
    
    echo "PROCESS STATUS"
    echo "--------------"
    echo "Language Server:"
    if pgrep -f language_server_linux_x64 > /dev/null; then
        echo "  ✓ Running (PIDs: $(pgrep -f language_server_linux_x64 | tr '\n' ' '))"
        ps aux | grep language_server_linux_x64 | grep -v grep | head -1
    else
        echo "  ✗ Not running"
    fi
    echo ""
    
    echo "Proxy Service:"
    if pgrep -f windsurf-proxy.py > /dev/null; then
        echo "  ✓ Running (PID: $(pgrep -f windsurf-proxy.py))"
    else
        echo "  ✗ Not running"
    fi
    echo ""
    
    echo "Windsurf Extension:"
    if pgrep -f "node.*windsurf" > /dev/null; then
        echo "  ✓ Running (PIDs: $(pgrep -f "node.*windsurf" | head -3 | tr '\n' ' '))"
    else
        echo "  ✗ Not running"
    fi
    echo ""
    
    echo "PORT STATUS"
    echo "-----------"
    echo "Original Ports (Localhost):"
    for port in 41801 38359; do
        if netstat -tulpn 2>/dev/null | grep -q ":$port"; then
            echo "  Port $port: ✓ Listening"
            netstat -tulpn 2>/dev/null | grep ":$port"
        else
            echo "  Port $port: ✗ Not listening"
        fi
    done
    echo ""
    
    echo "Proxy Ports (All Interfaces):"
    for port in 51801 48359; do
        if netstat -tulpn 2>/dev/null | grep -q ":$port"; then
            echo "  Port $port: ✓ Listening"
            netstat -tulpn 2>/dev/null | grep ":$port"
        else
            echo "  Port $port: ✗ Not listening"
        fi
    done
    echo ""
    
    echo "ACTIVE CONNECTIONS"
    echo "-----------------"
    echo "Established connections on Windsurf ports:"
    netstat -an | grep -E "41801|38359|51801|48359" | grep ESTABLISHED | head -10
    echo "Total: $(netstat -an | grep -E "41801|38359|51801|48359" | grep ESTABLISHED | wc -l) connections"
    echo ""
    
    echo "CONNECTIVITY TESTS"
    echo "-----------------"
    echo "Testing localhost connections:"
    for port in 41801 38359 51801 48359; do
        python3 -c "import socket; s=socket.socket(); r=s.connect_ex(('localhost',$port)); print('  localhost:$port - ' + ('✓ Open' if r==0 else '✗ Closed')); s.close()" 2>/dev/null
    done
    echo ""
    
    CONTAINER_IP=$(hostname -I | awk '{print $1}')
    echo "Testing container IP ($CONTAINER_IP) connections:"
    for port in 51801 48359; do
        python3 -c "import socket; s=socket.socket(); r=s.connect_ex(('$CONTAINER_IP',$port)); print('  $CONTAINER_IP:$port - ' + ('✓ Open' if r==0 else '✗ Closed')); s.close()" 2>/dev/null
    done
    echo ""
    
    echo "LOG FILES"
    echo "---------"
    echo "Proxy Log (last 10 lines):"
    if [ -f ~/windsurf-proxy.log ]; then
        tail -10 ~/windsurf-proxy.log 2>/dev/null | sed 's/^/  /'
    else
        echo "  No proxy log found"
    fi
    echo ""
    
    echo "Windsurf Log (last 10 lines):"
    WINDSURF_LOG=$(find ~/.windsurf-server/data/logs -name "1-windsurf.log" -type f 2>/dev/null | head -1)
    if [ -n "$WINDSURF_LOG" ]; then
        tail -10 "$WINDSURF_LOG" 2>/dev/null | sed 's/^/  /'
    else
        echo "  No Windsurf log found"
    fi
    echo ""
    
    echo "FILE SYSTEM"
    echo "-----------"
    echo "Windsurf installation:"
    if [ -d ~/.windsurf-server ]; then
        echo "  ✓ Found at ~/.windsurf-server"
        echo "  Version: $(ls ~/.windsurf-server/bin/ 2>/dev/null | head -1)"
    else
        echo "  ✗ Not found"
    fi
    echo ""
    
    echo "Proxy script:"
    if [ -f ~/windsurf-proxy.py ]; then
        echo "  ✓ Found at ~/windsurf-proxy.py"
        echo "  Size: $(stat -c%s ~/windsurf-proxy.py 2>/dev/null) bytes"
    else
        echo "  ✗ Not found"
    fi
    echo ""
    
    echo "CODER WORKSPACE"
    echo "--------------"
    echo "Workspace: ${CODER_WORKSPACE_NAME:-Not set}"
    echo "Agent URL: ${CODER_AGENT_URL:-Not set}"
    echo "Agent Token: ${CODER_AGENT_TOKEN:0:8}..."
    echo ""
    
    echo "DIAGNOSIS SUMMARY"
    echo "----------------"
    
    # Determine overall status
    ISSUES=()
    
    if ! pgrep -f language_server_linux_x64 > /dev/null; then
        ISSUES+=("Language server not running")
    fi
    
    if ! pgrep -f windsurf-proxy.py > /dev/null; then
        ISSUES+=("Proxy not running")
    fi
    
    if ! netstat -tulpn 2>/dev/null | grep -q ":51801"; then
        ISSUES+=("Proxy port 51801 not listening")
    fi
    
    if ! netstat -tulpn 2>/dev/null | grep -q ":48359"; then
        ISSUES+=("Proxy port 48359 not listening")
    fi
    
    if [ ${#ISSUES[@]} -eq 0 ]; then
        echo "✅ All systems operational"
        echo ""
        echo "If Cascade is still not working:"
        echo "  1. Reload Windsurf window (Cmd/Ctrl + R)"
        echo "  2. Clear Windsurf cache:"
        echo "     rm -rf ~/.codeium/windsurf/database/*"
        echo "  3. Restart Windsurf completely"
    else
        echo "❌ Issues detected:"
        for issue in "${ISSUES[@]}"; do
            echo "  • $issue"
        done
        echo ""
        echo "Recommended fix:"
        echo "  Run: ./install-fix.sh"
    fi
    
} | tee "$REPORT"

echo ""
echo "══════════════════════════════════════════════════════"
echo "Diagnostic report saved to: $REPORT"
echo ""
echo "To share this report:"
echo "  cat $REPORT | pbcopy  # Copy to clipboard (Mac)"
echo "  cat $REPORT | xclip   # Copy to clipboard (Linux)"
echo "══════════════════════════════════════════════════════"