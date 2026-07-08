#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${FUNCTION_IMAGE:-}" ]]; then
  echo "Set FUNCTION_IMAGE to the full OCIR image name."
  echo "Example for Vinhedo: export FUNCTION_IMAGE=vcp.ocir.io/<namespace>/failover/start-standby:1.0.0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNCTION_DIR="${SCRIPT_DIR}/../function"

if [[ -z "${PLATFORM:-}" ]]; then
  case "$(uname -m)" in
    x86_64|amd64)
      PLATFORM="linux/amd64"
      ;;
    aarch64|arm64)
      PLATFORM="linux/arm64"
      ;;
    *)
      echo "Could not detect the build platform automatically."
      echo "Set PLATFORM manually, for example: export PLATFORM=linux/amd64"
      exit 1
      ;;
  esac
fi

echo "Building ${FUNCTION_IMAGE}"
echo "Build platform: ${PLATFORM}"

if [[ "${PLATFORM}" == "linux/arm64" && "${FUNCTION_IMAGE}" != *arm64* ]]; then
  echo "Warning: building ARM64 image, but FUNCTION_IMAGE does not include 'arm64' in the tag."
  echo "Remember to set function_shape = GENERIC_ARM in Resource Manager."
fi

docker build --platform "${PLATFORM}" -t "${FUNCTION_IMAGE}" "${FUNCTION_DIR}"
docker push "${FUNCTION_IMAGE}"

echo "Pushed ${FUNCTION_IMAGE}"
