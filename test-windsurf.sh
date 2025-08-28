#!/bin/bash

# Windsurf Cascade Connection Tester
# Verifies the fix is working properly

echo "════════════════════════════════════════════"
echo "     Windsurf Cascade Connection Test"
echo "════════════════════════════════════════════"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_TESTS=0
PASSED_TESTS=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        if [ "$expected" = "pass" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ FAIL (expected to fail but passed)${NC}"
        fi
    else
        if [ "$expected" = "fail" ]; then
            echo -e "${GREEN}✓ PASS (correctly failed)${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
        fi
    fi
}

echo -e "${BLUE}═══ Process Status ═══${NC}"
run_test "Windsurf language server" "pgrep -f language_server_linux_x64" "pass"
run_test "Proxy service" "pgrep -f windsurf-proxy.py" "pass"
run_test "Windsurf extension host" "pgrep -f 'node.*windsurf'" "pass"

echo ""
echo -e "${BLUE}═══ Original Ports (Localhost) ═══${NC}"
run_test "Port 41801 (localhost)" "python3 -c 'import socket; s=socket.socket(); exit(0 if s.connect_ex((\"localhost\",41801))==0 else 1)'" "pass"
run_test "Port 38359 (localhost)" "python3 -c 'import socket; s=socket.socket(); exit(0 if s.connect_ex((\"localhost\",38359))==0 else 1)'" "pass"

echo ""
echo -e "${BLUE}═══ Proxy Ports (All Interfaces) ═══${NC}"
run_test "Port 51801 (0.0.0.0)" "python3 -c 'import socket; s=socket.socket(); exit(0 if s.connect_ex((\"localhost\",51801))==0 else 1)'" "pass"
run_test "Port 48359 (0.0.0.0)" "python3 -c 'import socket; s=socket.socket(); exit(0 if s.connect_ex((\"localhost\",48359))==0 else 1)'" "pass"

echo ""
echo -e "${BLUE}═══ Container Network Access ═══${NC}"
CONTAINER_IP=$(hostname -I | awk '{print $1}')
run_test "Port 51801 ($CONTAINER_IP)" "python3 -c 'import socket; s=socket.socket(); exit(0 if s.connect_ex((\"$CONTAINER_IP\",51801))==0 else 1)'" "pass"
run_test "Port 48359 ($CONTAINER_IP)" "python3 -c 'import socket; s=socket.socket(); exit(0 if s.connect_ex((\"$CONTAINER_IP\",48359))==0 else 1)'" "pass"

echo ""
echo -e "${BLUE}═══ Connection Status ═══${NC}"
CONNECTIONS=$(netstat -an 2>/dev/null | grep -E "51801|48359|41801|38359" | grep ESTABLISHED | wc -l)
echo "Active connections: $CONNECTIONS"

echo ""
echo "════════════════════════════════════════════"
echo -e "Test Results: ${GREEN}$PASSED_TESTS${NC}/${TOTAL_TESTS} passed"
echo "════════════════════════════════════════════"

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo ""
    echo -e "${GREEN}✅ All tests passed! Windsurf Cascade should be working.${NC}"
    echo ""
    echo "If Cascade is still not loading:"
    echo "  1. Reload the Windsurf window (Cmd/Ctrl + R)"
    echo "  2. Wait 10-15 seconds for initialization"
    echo "  3. Try opening a new file and triggering Cascade"
    exit 0
else
    echo ""
    echo -e "${RED}⚠ Some tests failed. Cascade may not work properly.${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Run: ./install-fix.sh"
    echo "  2. Check logs: tail -f ~/windsurf-proxy.log"
    echo "  3. Run diagnostics: ./diagnostics.sh"
    exit 1
fi