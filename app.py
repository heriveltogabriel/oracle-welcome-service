#!/usr/bin/env python3
import html
import os
import socket
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "80"))
HEALTHY_PATHS = ("/health-check", "/health", "/healthz")
UNHEALTHY_PATHS = ("/health-check-error", "/health-error", "/healthz-error")


def render_home() -> bytes:
    hostname = html.escape(socket.gethostname())
    now = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
    now = html.escape(now)

    page = f"""<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bem-vindo Oracle</title>
  <style>
    :root {{
      --oracle-red: #c74634;
      --ink: #1f2937;
      --muted: #5b6472;
      --paper: #fbf9f7;
      --card: #ffffff;
      --line: #e5e0dc;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      min-height: 100vh;
      font-family: Arial, Helvetica, sans-serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(199, 70, 52, 0.16), transparent 30%),
        linear-gradient(135deg, #fff 0%, var(--paper) 60%, #f6efeb 100%);
    }}
    .wrap {{
      width: min(1080px, calc(100% - 40px));
      min-height: 100vh;
      margin: 0 auto;
      display: grid;
      place-items: center;
      padding: 56px 0;
    }}
    .card {{
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 22px;
      background: rgba(255, 255, 255, 0.84);
      box-shadow: 0 28px 80px rgba(31, 41, 55, 0.12);
      overflow: hidden;
    }}
    .top {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 20px;
      padding: 24px 28px;
      border-bottom: 1px solid var(--line);
    }}
    .brand {{
      color: var(--oracle-red);
      font-size: 30px;
      font-weight: 900;
      letter-spacing: 2px;
    }}
    .status {{
      display: inline-flex;
      align-items: center;
      gap: 8px;
      color: #166534;
      font-size: 14px;
      font-weight: 800;
    }}
    .dot {{
      width: 11px;
      height: 11px;
      border-radius: 999px;
      background: #22c55e;
      box-shadow: 0 0 0 5px rgba(34, 197, 94, 0.14);
    }}
    .hero {{
      display: grid;
      grid-template-columns: 1.2fr 0.8fr;
      gap: 34px;
      padding: 56px 52px;
    }}
    h1 {{
      margin: 0;
      max-width: 680px;
      font-size: clamp(42px, 7vw, 78px);
      line-height: 0.98;
      letter-spacing: -2px;
    }}
    .lead {{
      margin: 24px 0 0;
      max-width: 620px;
      color: var(--muted);
      font-size: 21px;
      line-height: 1.55;
    }}
    .meta {{
      align-self: center;
      border: 1px solid var(--line);
      border-radius: 18px;
      background: var(--card);
      padding: 24px;
    }}
    .meta div + div {{
      margin-top: 18px;
      padding-top: 18px;
      border-top: 1px solid var(--line);
    }}
    .meta span {{
      display: block;
      margin-bottom: 6px;
      color: var(--muted);
      font-size: 13px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.8px;
    }}
    .meta strong {{
      display: block;
      font-size: 22px;
      word-break: break-word;
    }}
    @media (max-width: 820px) {{
      .hero {{ grid-template-columns: 1fr; padding: 38px 28px; }}
      .top {{ align-items: flex-start; flex-direction: column; }}
    }}
  </style>
</head>
<body>
  <main class="wrap">
    <section class="card" aria-label="Página de boas-vindas Oracle">
      <div class="top">
        <div class="brand">ORACLE</div>
        <div class="status"><span class="dot"></span> Serviço Python ativo</div>
      </div>
      <div class="hero">
        <div>
          <h1>Bem-vindo Oracle</h1>
          <p class="lead">
            Aplicação Python rodando na porta 80. Esta página pode ser usada
            para validar Load Balancer, Instance Pool, autoscaling e health check.
          </p>
        </div>
        <aside class="meta">
          <div>
            <span>Hostname</span>
            <strong>{hostname}</strong>
          </div>
          <div>
            <span>Porta</span>
            <strong>{PORT}</strong>
          </div>
          <div>
            <span>Horário</span>
            <strong>{now}</strong>
          </div>
        </aside>
      </div>
    </section>
  </main>
</body>
</html>
"""
    return page.encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    server_version = "OracleWelcomePython/1.0"

    def do_GET(self):
        path = self.path.split("?", 1)[0]

        if path in HEALTHY_PATHS:
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(b"OK\n")
            return

        if path in UNHEALTHY_PATHS:
            self.send_response(HTTPStatus.INTERNAL_SERVER_ERROR)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(b"ERROR\n")
            return

        if path not in ("/", "/index.html"):
            self.send_error(HTTPStatus.NOT_FOUND, "Not found")
            return

        body = render_home()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {self.log_date_time_string()} - {fmt % args}", flush=True)


def main():
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Oracle Welcome app listening on http://{HOST}:{PORT}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
