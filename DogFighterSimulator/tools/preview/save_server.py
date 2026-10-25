"""Servidorzinho local que GUARDA imagens PNG mandadas pela página de prévia (render.html) — 2026-10.

Uso:  python tools/preview/save_server.py 8766 Previa_Habilidades
Na página: fetch('http://localhost:8766/save', { method: 'POST', body: JSON.stringify({ name: 'foto.png', png: dataURL }) })
Só aceita nomes simples (.png) e grava dentro da pasta escolhida.
"""
import base64, json, os, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, sys.argv[2] if len(sys.argv) > 2 else 'Previa_Habilidades')
os.makedirs(OUT, exist_ok=True)


class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors()
        self.end_headers()

    def do_POST(self):
        size = int(self.headers.get('Content-Length', 0))
        data = json.loads(self.rfile.read(size))
        name = os.path.basename(str(data.get('name', 'foto.png')))
        if not name.lower().endswith('.png'):
            name += '.png'
        png = base64.b64decode(str(data['png']).split(',', 1)[-1])
        # "folder" opcional: outra pasta simples dentro do projeto (ex.: Previa_Cachorros_Novos)
        folder = str(data.get('folder') or '')
        out = OUT
        if folder and folder.replace('_', '').isalnum():
            out = os.path.join(ROOT, folder)
            os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, name), 'wb') as fh:
            fh.write(png)
        self.send_response(200)
        self._cors()
        self.end_headers()
        self.wfile.write(b'ok')

    def do_GET(self):
        self.send_response(200)
        self._cors()
        self.end_headers()
        self.wfile.write(b'servidor de fotos ok')

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    print('guardando em', OUT, 'porta', PORT, flush=True)
    ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
