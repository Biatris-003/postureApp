#!/usr/bin/env python3
"""
Simple local server for Exercise Coach.
Needed because webcam access requires a proper HTTP server
(file:// protocol blocks camera permissions).
"""
import http.server
import socketserver
import os
import webbrowser
from threading import Timer

PORT = 8080
DIR  = os.path.dirname(os.path.abspath(__file__))

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIR, **kwargs)

    def log_message(self, format, *args):
        pass  # Suppress request logs for cleanliness

class ReusableHTTPServer(socketserver.TCPServer):
    allow_reuse_address = True  # Allow immediate port reuse

def open_browser():
    webbrowser.open(f'http://localhost:{PORT}/index.html')

print(f"""
╔══════════════════════════════════════╗
║       Exercise Coach  🏋️             ║
╠══════════════════════════════════════╣
║  Server: http://localhost:{PORT}     ║
║  Press  Ctrl+C  to stop              ║
╚══════════════════════════════════════╝
""")

Timer(1.0, open_browser).start()

with ReusableHTTPServer(('', PORT), Handler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nServer stopped.')
