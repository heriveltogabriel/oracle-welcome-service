#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-oracle-welcome}"
SERVICE_NAME="${SERVICE_NAME:-oracle-welcome}"
INSTALL_DIR="${INSTALL_DIR:-/opt/oracle-welcome}"
PORT="${PORT:-80}"
HOST="${HOST:-0.0.0.0}"
SERVICE_USER="${SERVICE_USER:-oracle-welcome}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SOURCE="${SCRIPT_DIR}/app.py"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Execute com sudo ou root:"
  echo "  sudo bash ${0}"
  exit 1
fi

if [[ ! -f "${APP_SOURCE}" ]]; then
  echo "Arquivo app.py não encontrado em: ${APP_SOURCE}"
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemd/systemctl não encontrado. Este instalador foi feito para Linux com systemd."
  exit 1
fi

install_python() {
  if command -v python3 >/dev/null 2>&1; then
    return
  fi

  echo "python3 não encontrado. Tentando instalar..."
  if command -v dnf >/dev/null 2>&1; then
    dnf install -y python3
  elif command -v yum >/dev/null 2>&1; then
    yum install -y python3
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y python3
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install python3
  else
    echo "Não consegui instalar python3 automaticamente. Instale python3 e rode novamente."
    exit 1
  fi
}

open_firewall() {
  if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http >/dev/null
    firewall-cmd --reload >/dev/null
    echo "Firewall: serviço HTTP liberado no firewalld."
    return
  fi

  if command -v ufw >/dev/null 2>&1 && ufw status | grep -qi "Status: active"; then
    ufw allow 80/tcp
    echo "Firewall: porta 80/tcp liberada no ufw."
    return
  fi

  echo "Firewall: firewalld/ufw ativo não detectado. Verifique regras da VM e Security List/NSG no OCI."
}

if command -v ss >/dev/null 2>&1 && ss -ltn "( sport = :${PORT} )" | grep -q ":${PORT}"; then
  echo "A porta ${PORT} já está em uso. Pare o serviço atual ou escolha outra porta:"
  echo "  sudo PORT=8080 bash install.sh"
  exit 1
fi

install_python
PYTHON_BIN="$(command -v python3)"

if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
  if command -v useradd >/dev/null 2>&1; then
    useradd --system --home-dir "${INSTALL_DIR}" --shell /usr/sbin/nologin "${SERVICE_USER}" 2>/dev/null \
      || useradd --system --home-dir "${INSTALL_DIR}" --shell /sbin/nologin "${SERVICE_USER}"
  else
    echo "Comando useradd não encontrado."
    exit 1
  fi
fi

install -d -m 0755 -o "${SERVICE_USER}" -g "${SERVICE_USER}" "${INSTALL_DIR}"
install -m 0755 -o "${SERVICE_USER}" -g "${SERVICE_USER}" "${APP_SOURCE}" "${INSTALL_DIR}/app.py"

cat > "${SERVICE_FILE}" <<SERVICE
[Unit]
Description=Oracle Welcome Python web service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
Environment=HOST=${HOST}
Environment=PORT=${PORT}
ExecStart=${PYTHON_BIN} ${INSTALL_DIR}/app.py
Restart=always
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

open_firewall

echo
echo "Status do serviço:"
systemctl --no-pager --full status "${SERVICE_NAME}" || true

echo
echo "Teste local:"
if command -v curl >/dev/null 2>&1; then
  curl -fsS "http://127.0.0.1:${PORT}/health-check"
else
  "${PYTHON_BIN}" - <<PY
from urllib.request import urlopen
print(urlopen("http://127.0.0.1:${PORT}/health-check", timeout=5).read().decode(), end="")
PY
fi

echo
echo "Instalação concluída."
echo "Abra no navegador: http://IP_DA_VM/"
echo "Health check para Load Balancer/OCI Health Checks: http://IP_DA_VM/health-check"
echo "Health check de erro para teste: http://IP_DA_VM/health-check-error"
