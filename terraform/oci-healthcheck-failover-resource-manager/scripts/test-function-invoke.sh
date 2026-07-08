#!/usr/bin/env bash
set -euo pipefail

FUNCTION_ID="${1:-${FUNCTION_ID:-}}"
RESPONSE_FILE="${RESPONSE_FILE:-response.json}"

if [[ -z "${FUNCTION_ID}" ]]; then
  echo "Usage: FUNCTION_ID=<ocid1.fnfunc...> $0"
  echo "   or: $0 <ocid1.fnfunc...>"
  exit 1
fi

echo "Function ID: ${FUNCTION_ID}"
echo "Reading Function config..."

CONFIG_JSON="$(oci fn function get --function-id "${FUNCTION_ID}" --query 'data.config' --output json)"
EXPECTED_ALARM_OCID="$(oci fn function get --function-id "${FUNCTION_ID}" --query 'data.config."EXPECTED_ALARM_OCID"' --raw-output)"

if [[ -z "${EXPECTED_ALARM_OCID}" || "${EXPECTED_ALARM_OCID}" == "null" ]]; then
  echo "Could not read EXPECTED_ALARM_OCID from Function config."
  echo "${CONFIG_JSON}"
  exit 1
fi

echo "Expected alarm OCID: ${EXPECTED_ALARM_OCID}"

PAYLOAD_FILE="$(mktemp /tmp/fn-alarm-payload.XXXXXX.json)"

cat > "${PAYLOAD_FILE}" <<EOF
{
  "type": "com.oraclecloud.monitoring.alarm.status",
  "alarmId": "${EXPECTED_ALARM_OCID}",
  "status": "FIRING",
  "alarmMetaData": [
    {
      "id": "${EXPECTED_ALARM_OCID}",
      "status": "FIRING"
    }
  ]
}
EOF

echo "Payload:"
cat "${PAYLOAD_FILE}"
echo

rm -f "${RESPONSE_FILE}"

echo "Invoking Function..."
oci fn function invoke \
  --function-id "${FUNCTION_ID}" \
  --body "file://${PAYLOAD_FILE}" \
  --file "${RESPONSE_FILE}"

echo
echo "Response:"
cat "${RESPONSE_FILE}"
echo

echo "Interpretation:"
echo "- action START: standby VM start was requested."
echo "- action noop: standby VM was already not STOPPED."
echo "- NotAuthorizedOrNotFound or 502: check Dynamic Group and Policy."
