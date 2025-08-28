#!/bin/bash

# Windsurf Cascade Monitoring & Auto-Recovery Script
# Continuously monitors and maintains the Windsurf proxy fix

# Configuration
PROXY_SCRIPT="$HOME/windsurf-proxy.py"
PROXY_LOG="$HOME/windsurf-proxy.log"
MONITOR_LOG="$HOME/windsurf-monitor.log"
CHECK_INTERVAL=30  # seconds
MAX_RETRIES=3
ALERT_THRESHOLD=5  # failures before alerting

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
FAILURE_COUNT=0
RECOVERY_COUNT=0
UPTIME_START=$(date +%s)

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$MONITOR_LOG"
    
    case $level in
        ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
        WARNING) echo -e "${YELLOW}[WARN]${NC} $message" ;;
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[OK]${NC} $message" ;;
    esac
}

# Check if proxy is healthy
check_proxy_health() {
    local healthy=true
    
    # Check if process is running
    if ! pgrep -f windsurf-proxy.py > /dev/null 2>&1; then
        log ERROR "Proxy process not found"
        healthy=false
    fi
    
    # Check if ports are listening
    for port in 51801 48359; do
        if ! netstat -tulpn 2>/dev/null | grep -q ":$port"; then
            log ERROR "Port $port not listening"
            healthy=false
        fi
    done
    
    # Check port connectivity
    for port in 51801 48359; do
        if ! python3 -c "import socket; s=socket.socket(); exit(0 if s.connect_ex(('localhost',$port))==0 else 1)" 2>/dev/null; then
            log ERROR "Cannot connect to port $port"
            healthy=false
        fi
    done
    
    # Check if language server is running
    if ! pgrep -f language_server_linux_x64 > /dev/null 2>&1; then
        log WARNING "Language server not running (may be normal if Windsurf is closed)"
    fi
    
    if [ "$healthy" = true ]; then
        return 0
    else
        return 1
    fi
}

# Restart the proxy
restart_proxy() {
    log INFO "Attempting to restart proxy..."
    
    # Kill existing proxy
    pkill -f windsurf-proxy.py 2>/dev/null
    sleep 2
    
    # Start new proxy instance
    if [ -f "$PROXY_SCRIPT" ]; then
        nohup python3 "$PROXY_SCRIPT" > "$PROXY_LOG" 2>&1 &
        local pid=$!
        sleep 3
        
        # Verify it started
        if kill -0 $pid 2>/dev/null; then
            log SUCCESS "Proxy restarted successfully (PID: $pid)"
            return 0
        else
            log ERROR "Failed to restart proxy"
            return 1
        fi
    else
        log ERROR "Proxy script not found at $PROXY_SCRIPT"
        return 1
    fi
}

# Send alert (customize based on your notification system)
send_alert() {
    local message="$1"
    log ERROR "ALERT: $message"
    
    # Add your alerting mechanism here:
    # - Send to Slack: curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" YOUR_WEBHOOK_URL
    # - Send email: echo "$message" | mail -s "Windsurf Monitor Alert" your-email@example.com
    # - Write to system log: logger -t windsurf-monitor "$message"
    
    # For now, just create an alert file
    echo "$(date): $message" >> "$HOME/windsurf-alerts.txt"
}

# Display status dashboard
show_status() {
    clear
    echo "╔════════════════════════════════════════════╗"
    echo "║     Windsurf Cascade Monitor Dashboard    ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""
    
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local uptime=$(($(date +%s) - UPTIME_START))
    local uptime_hours=$((uptime / 3600))
    local uptime_mins=$(((uptime % 3600) / 60))
    
    echo "Status Time: $current_time"
    echo "Monitor Uptime: ${uptime_hours}h ${uptime_mins}m"
    echo ""
    
    echo "Service Status:"
    if pgrep -f windsurf-proxy.py > /dev/null; then
        echo -e "  Proxy Process: ${GREEN}✓ Running${NC}"
    else
        echo -e "  Proxy Process: ${RED}✗ Not Running${NC}"
    fi
    
    if pgrep -f language_server > /dev/null; then
        echo -e "  Language Server: ${GREEN}✓ Running${NC}"
    else
        echo -e "  Language Server: ${YELLOW}⚠ Not Running${NC}"
    fi
    echo ""
    
    echo "Port Status:"
    for port in 51801 48359; do
        if netstat -tulpn 2>/dev/null | grep -q ":$port"; then
            echo -e "  Port $port: ${GREEN}✓ Listening${NC}"
        else
            echo -e "  Port $port: ${RED}✗ Not Listening${NC}"
        fi
    done
    echo ""
    
    echo "Statistics:"
    echo "  Failure Count: $FAILURE_COUNT"
    echo "  Recovery Count: $RECOVERY_COUNT"
    echo "  Alert Threshold: $ALERT_THRESHOLD failures"
    echo ""
    
    local connections=$(netstat -an 2>/dev/null | grep -E "51801|48359" | grep ESTABLISHED | wc -l)
    echo "Active Connections: $connections"
    echo ""
    echo "Next check in ${CHECK_INTERVAL} seconds..."
    echo "Press Ctrl+C to stop monitoring"
}

# Cleanup on exit
cleanup() {
    log INFO "Monitor shutting down..."
    echo ""
    echo "Monitor stopped. Total runtime: $(($(date +%s) - UPTIME_START)) seconds"
    echo "Total recoveries performed: $RECOVERY_COUNT"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main monitoring loop
main() {
    log INFO "Windsurf monitor started"
    log INFO "Checking every ${CHECK_INTERVAL} seconds"
    
    # Initial check
    if ! check_proxy_health; then
        log WARNING "Initial health check failed, attempting recovery..."
        restart_proxy
    fi
    
    while true; do
        show_status
        
        if check_proxy_health; then
            log SUCCESS "Health check passed"
            FAILURE_COUNT=0
        else
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            log WARNING "Health check failed (count: $FAILURE_COUNT)"
            
            if [ $FAILURE_COUNT -ge $ALERT_THRESHOLD ]; then
                send_alert "Windsurf proxy has failed $FAILURE_COUNT times"
            fi
            
            # Attempt recovery
            local retry=0
            local recovered=false
            
            while [ $retry -lt $MAX_RETRIES ] && [ "$recovered" = false ]; do
                retry=$((retry + 1))
                log INFO "Recovery attempt $retry of $MAX_RETRIES"
                
                if restart_proxy; then
                    sleep 3
                    if check_proxy_health; then
                        recovered=true
                        RECOVERY_COUNT=$((RECOVERY_COUNT + 1))
                        log SUCCESS "Recovery successful"
                        FAILURE_COUNT=0
                    fi
                fi
                
                if [ "$recovered" = false ] && [ $retry -lt $MAX_RETRIES ]; then
                    log WARNING "Recovery attempt $retry failed, waiting before retry..."
                    sleep 5
                fi
            done
            
            if [ "$recovered" = false ]; then
                send_alert "Failed to recover Windsurf proxy after $MAX_RETRIES attempts"
                log ERROR "All recovery attempts failed"
            fi
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        --daemon)
            # Run in background
            nohup "$0" > /dev/null 2>&1 &
            echo "Monitor started in background (PID: $!)"
            exit 0
            ;;
        --status)
            # One-time status check
            show_status
            exit 0
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --interval SECONDS  Set check interval (default: 30)"
            echo "  --daemon           Run in background"
            echo "  --status           Show current status and exit"
            echo "  --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run interactively"
            echo "  $0 --daemon           # Run in background"
            echo "  $0 --interval 60      # Check every 60 seconds"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Start monitoring
main