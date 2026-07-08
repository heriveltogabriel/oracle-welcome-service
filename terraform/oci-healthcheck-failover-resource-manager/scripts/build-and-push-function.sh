#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${FUNCTION_IMAGE:-}" ]]; then
  echo "Set FUNCTION_IMAGE to the full OCIR image name."
  echo "Example for Vinhedo: export FUNCTION_IMAGE=vcp.ocir.io/<namespace>/failover/start-standby:1.0.0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNCTION_DIR="${SCRIPT_DIR}/../function"
PLATFORM="${PLATFORM:-linux/amd64}"

docker build --platform "${PLATFORM}" -t "${FUNCTION_IMAGE}" "${FUNCTION_DIR}"
docker push "${FUNCTION_IMAGE}"

echo "Pushed ${FUNCTION_IMAGE}"
