#!/usr/bin/env bash
set -euo pipefail

DURATION_MINUTES="${1:-10}"
WORKERS="${2:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"

if ! [[ "${DURATION_MINUTES}" =~ ^[0-9]+$ ]] || [[ "${DURATION_MINUTES}" -lt 1 ]]; then
  echo "Uso: $0 <minutos> [workers]"
  echo "Exemplo: $0 10"
  echo "Exemplo: $0 15 4"
  exit 1
fi

if ! [[ "${WORKERS}" =~ ^[0-9]+$ ]] || [[ "${WORKERS}" -lt 1 ]]; then
  echo "Workers precisa ser um número maior que zero."
  exit 1
fi

DURATION_SECONDS=$((DURATION_MINUTES * 60))
PIDS=()

cleanup() {
  echo
  echo "Parando carga de CPU..."
  for pid in "${PIDS[@]:-}"; do
    kill "${pid}" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  echo "CPU stress finalizado."
}

trap cleanup EXIT INT TERM

echo "Iniciando carga de CPU"
echo "Duração: ${DURATION_MINUTES} minuto(s)"
echo "Workers: ${WORKERS}"
echo "Para parar antes: Ctrl+C"
echo

for i in $(seq 1 "${WORKERS}"); do
  (
    end_time=$((SECONDS + DURATION_SECONDS))
    value=0
    while [[ "${SECONDS}" -lt "${end_time}" ]]; do
      value=$(( (value + 1) % 999983 ))
    done
  ) &
  PIDS+=("$!")
done

echo "Processos iniciados: ${PIDS[*]}"
echo "Acompanhe em outro terminal com: top ou uptime"

sleep "${DURATION_SECONDS}"
