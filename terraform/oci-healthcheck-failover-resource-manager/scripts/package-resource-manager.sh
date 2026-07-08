#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT="${1:-../oci-healthcheck-failover-resource-manager-$(date +%Y%m%d%H%M%S)-no-schema.zip}"

cd "${PROJECT_DIR}"

if [ -e "${OUTPUT}" ]; then
  echo "Output already exists: ${OUTPUT}" >&2
  echo "Choose another output file name or delete the old zip first." >&2
  exit 1
fi

zip -r "${OUTPUT}" . \
  -x 'schema.yaml' \
  -x '*.terraform*' \
  -x '*.tfstate*' \
  -x '*.zip' \
  -x '.DS_Store'

echo "Created ${OUTPUT}"
