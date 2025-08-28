#!/usr/bin/env python3
import socket
import threading
import sys

def proxy_connection(client_socket, target_host, target_port):
    try:
        # Connect to target
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((target_host, target_port))
        
        # Start forwarding threads
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
        
        # Create bidirectional forwarding
        t1 = threading.Thread(target=forward, args=(client_socket, target_socket))
        t2 = threading.Thread(target=forward, args=(target_socket, client_socket))
        t1.start()
        t2.start()
        
    except Exception as e:
        print(f"Proxy error: {e}")
        client_socket.close()

def start_proxy(listen_port, target_port):
    # Create server socket that listens on all interfaces
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind(('0.0.0.0', listen_port))
    server_socket.listen(5)
    
    print(f"Proxy listening on 0.0.0.0:{listen_port} -> localhost:{target_port}")
    
    while True:
        client_socket, addr = server_socket.accept()
        print(f"Connection from {addr}")
        thread = threading.Thread(target=proxy_connection, args=(client_socket, 'localhost', target_port))
        thread.daemon = True
        thread.start()

if __name__ == "__main__":
    # Start proxies for both Windsurf ports
    t1 = threading.Thread(target=start_proxy, args=(51801, 41801))
    t2 = threading.Thread(target=start_proxy, args=(48359, 38359))
    t1.daemon = True
    t2.daemon = True
    t1.start()
    t2.start()
    
    print("Windsurf proxy running on ports 51801->41801 and 48359->38359")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            threading.Event().wait(1)
    except KeyboardInterrupt:
        print("\nProxy stopped")
