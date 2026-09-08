"""Serve the exported Godot game; same assets/scripts as Android, never a WebView wrapper."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import argparse
class Handler(SimpleHTTPRequestHandler):
    extensions_map={**SimpleHTTPRequestHandler.extensions_map,'.wasm':'application/wasm','.pck':'application/octet-stream'}
    def end_headers(self):
        self.send_header('Cache-Control','no-cache')
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        super().end_headers()
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8080);args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]/'preview'
    ThreadingHTTPServer(('0.0.0.0',args.port),lambda *a,**kw:Handler(*a,directory=str(root),**kw)).serve_forever()
