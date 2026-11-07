#!/usr/bin/env python3
"""Un servidor HTTP de git para las pruebas: git http-backend detrás de http.server (sin cifrar).

    tests/servidor_git.py CAJÓN_RAÍZ PUERTO [DIRECCIÓN]

Sirve los repositorios de CAJÓN_RAÍZ en http://127.0.0.1:PUERTO/<nombre> (o en DIRECCIÓN), con push permitido
(http.receivepack). Las peticiones se apuntan en CAJÓN_RAÍZ/peticiones.txt, con el Host y "auth" si traen
Authorization. Con chunked=1 en el entorno, contesta en trozos
(Transfer-Encoding: chunked), como GitHub.
"""
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

raiz = os.path.abspath(sys.argv[1])
puerto = int(sys.argv[2])
direccion = sys.argv[3] if len(sys.argv) > 3 else "127.0.0.1"
trozos = os.environ.get("chunked") == "1"


class Manejador(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _cgi(self):
        ruta, _, consulta = self.path.partition("?")
        n = int(self.headers.get("Content-Length") or 0)
        cuerpo = self.rfile.read(n) if n else b""
        env = dict(os.environ, GIT_PROJECT_ROOT=raiz, GIT_HTTP_EXPORT_ALL="1", REQUEST_METHOD=self.command,
                   PATH_INFO=ruta, QUERY_STRING=consulta, CONTENT_TYPE=self.headers.get("Content-Type") or "",
                   CONTENT_LENGTH=str(len(cuerpo)), REMOTE_ADDR="127.0.0.1", REMOTE_USER="amiga")
        p = subprocess.run(["git", "http-backend"], input=cuerpo, env=env, capture_output=True)
        cab, _, datos = p.stdout.partition(b"\r\n\r\n")
        if not _:
            cab, _, datos = p.stdout.partition(b"\n\n")
        estado = 200
        cabeceras = []
        for linea in cab.decode("latin-1").splitlines():
            k, _, v = linea.partition(":")
            if k.lower() == "status":
                estado = int(v.strip().split()[0])
            elif k:
                cabeceras.append((k, v.strip()))
        with open(os.path.join(raiz, "peticiones.txt"), "a") as f:
            f.write(f"{self.command} {self.path} {len(cuerpo)} -> {estado} {len(datos)} {self.headers.get('User-Agent')} Host={self.headers.get('Host')}{' auth' if self.headers.get('Authorization') else ''}\n")
        self.send_response(estado)
        for k, v in cabeceras:
            self.send_header(k, v)
        if trozos:
            self.send_header("Transfer-Encoding", "chunked")
        else:
            self.send_header("Content-Length", str(len(datos)))
        self.send_header("Connection", "close")
        self.end_headers()
        if trozos:
            for i in range(0, len(datos), 1000):
                t = datos[i:i + 1000]
                self.wfile.write(b"%x\r\n" % len(t) + t + b"\r\n")
            self.wfile.write(b"0\r\n\r\n")
        else:
            self.wfile.write(datos)
        self.close_connection = True

    do_GET = _cgi
    do_POST = _cgi


ThreadingHTTPServer((direccion, puerto), Manejador).serve_forever()
