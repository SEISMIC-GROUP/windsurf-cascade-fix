# Coder Template Patch for Windsurf Cascade Fix
# Add this to your existing Coder template to permanently fix the issue

# Option 1: Add to coder_agent startup script
resource "coder_agent" "main" {
  # ... existing configuration ...
  
  startup_script = <<-EOT
    # Existing startup commands...
    
    # Windsurf Cascade Fix - TCP Proxy for localhost-only bindings
    echo "Starting Windsurf proxy fix..."
    
    # Create the proxy script if it doesn't exist
    if [ ! -f ~/windsurf-proxy.py ]; then
      cat > ~/windsurf-proxy.py << 'PROXY'
#!/usr/bin/env python3
import socket
import threading
import sys

def proxy_connection(client_socket, target_host, target_port):
    try:
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((target_host, target_port))
        
        def forward(source, destination):
            try:
                while True:
                    data = source.recv(4096)
                    if not data:
                        break
                    destination.send(data)
            except:
                pass
            finally:
                source.close()
                destination.close()
        
        t1 = threading.Thread(target=forward, args=(client_socket, target_socket))
        t2 = threading.Thread(target=forward, args=(target_socket, client_socket))
        t1.start()
        t2.start()
        
    except Exception as e:
        print(f"Proxy error: {e}")
        client_socket.close()

def start_proxy(listen_port, target_port):
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind(('0.0.0.0', listen_port))
    server_socket.listen(5)
    
    print(f"Proxy listening on 0.0.0.0:{listen_port} -> localhost:{target_port}")
    
    while True:
        client_socket, addr = server_socket.accept()
        thread = threading.Thread(target=proxy_connection, args=(client_socket, 'localhost', target_port))
        thread.daemon = True
        thread.start()

if __name__ == "__main__":
    t1 = threading.Thread(target=start_proxy, args=(51801, 41801))
    t2 = threading.Thread(target=start_proxy, args=(48359, 38359))
    t1.daemon = True
    t2.daemon = True
    t1.start()
    t2.start()
    
    print("Windsurf proxy running on ports 51801->41801 and 48359->38359")
    
    try:
        while True:
            threading.Event().wait(1)
    except KeyboardInterrupt:
        print("\\nProxy stopped")
PROXY
      chmod +x ~/windsurf-proxy.py
    fi
    
    # Start proxy if not already running
    if ! pgrep -f windsurf-proxy.py > /dev/null 2>&1; then
      nohup python3 ~/windsurf-proxy.py > ~/windsurf-proxy.log 2>&1 &
      echo "Windsurf proxy started with PID $!"
    else
      echo "Windsurf proxy already running"
    fi
    
    # Existing startup commands continue...
  EOT
  
  # ... rest of configuration ...
}

# Option 2: Create dedicated Coder apps for the proxy ports
resource "coder_app" "windsurf_server" {
  agent_id     = coder_agent.main.id
  slug         = "windsurf-server"
  display_name = "Windsurf Server (Proxy)"
  url          = "http://localhost:51801"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
  
  healthcheck {
    url       = "http://localhost:51801"
    interval  = 30
    threshold = 3
  }
}

resource "coder_app" "windsurf_lsp" {
  agent_id     = coder_agent.main.id
  slug         = "windsurf-lsp"
  display_name = "Windsurf LSP (Proxy)"
  url          = "http://localhost:48359"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
  
  healthcheck {
    url       = "http://localhost:48359"
    interval  = 30
    threshold = 3
  }
}

# Option 3: Add environment variables for Windsurf configuration
resource "coder_agent" "main" {
  # ... existing configuration ...
  
  env = {
    # Existing environment variables...
    
    # Windsurf proxy configuration
    WINDSURF_PROXY_ENABLED  = "true"
    WINDSURF_SERVER_PORT    = "51801"
    WINDSURF_LSP_PORT       = "48359"
    WINDSURF_ORIGINAL_SERVER = "41801"
    WINDSURF_ORIGINAL_LSP   = "38359"
  }
  
  # ... rest of configuration ...
}

# Option 4: Add metadata for tracking
resource "coder_metadata" "windsurf_fix" {
  resource_id = coder_agent.main.id
  count       = 1
  
  item {
    key   = "Windsurf Proxy Status"
    value = "Enabled - Ports 51801/48359"
  }
  
  item {
    key   = "Fix Version"
    value = "1.0 - TCP Proxy Bridge"
  }
  
  item {
    key   = "Documentation"
    value = "https://github.com/coder/coder/issues/windsurf-cascade-fix"
  }
}

# Option 5: Add startup script as a separate script resource
resource "coder_script" "windsurf_fix" {
  agent_id     = coder_agent.main.id
  display_name = "Windsurf Cascade Fix"
  icon         = "/icon/bug.svg"
  script = <<-EOT
    #!/bin/bash
    
    # Check if fix is needed
    if pgrep -f windsurf-proxy.py > /dev/null; then
      echo "✅ Windsurf proxy already running"
      exit 0
    fi
    
    # Apply the fix
    echo "🔧 Applying Windsurf Cascade fix..."
    
    # Download and install proxy
    curl -sL https://your-domain.com/windsurf-proxy.py -o ~/windsurf-proxy.py
    chmod +x ~/windsurf-proxy.py
    
    # Start proxy
    nohup python3 ~/windsurf-proxy.py > ~/windsurf-proxy.log 2>&1 &
    
    echo "✅ Fix applied! Proxy running on ports 51801 and 48359"
  EOT
  
  run_on_start = true
}

# Variables for customization
variable "windsurf_proxy_enabled" {
  description = "Enable Windsurf Cascade proxy fix"
  type        = bool
  default     = true
}

variable "windsurf_proxy_ports" {
  description = "Proxy port mappings"
  type = object({
    server_proxy = number
    lsp_proxy    = number
    server_orig  = number
    lsp_orig     = number
  })
  default = {
    server_proxy = 51801
    lsp_proxy    = 48359
    server_orig  = 41801
    lsp_orig     = 38359
  }
}