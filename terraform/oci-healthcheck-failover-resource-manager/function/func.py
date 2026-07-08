import io
import json
import logging
import os
from typing import Any

import oci

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def _load_payload(data: io.BytesIO | None) -> Any:
    if data is None:
        return {}

    raw = data.getvalue()
    if not raw:
        return {}

    text = raw.decode("utf-8")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {"raw": text}


def _payload_text(payload: Any) -> str:
    try:
        return json.dumps(payload, sort_keys=True)
    except TypeError:
        return str(payload)


def _should_start(payload: Any) -> tuple[bool, str]:
    expected_alarm_ocid = os.environ.get("EXPECTED_ALARM_OCID", "").strip()
    require_firing = os.environ.get("REQUIRE_FIRING_STATE", "true").lower() == "true"
    text = _payload_text(payload)

    if expected_alarm_ocid and expected_alarm_ocid not in text:
        return False, "notification does not match expected alarm OCID"

    if require_firing and "FIRING" not in text:
        return False, "notification is not a FIRING alarm"

    return True, "notification accepted"


def handler(ctx, data: io.BytesIO | None = None):
    standby_instance_ocid = os.environ["STANDBY_INSTANCE_OCID"]
    region = os.environ.get("OCI_REGION")
    payload = _load_payload(data)

    should_start, reason = _should_start(payload)
    if not should_start:
        LOGGER.info("Ignoring notification: %s", reason)
        return {"action": "ignored", "reason": reason}

    signer = oci.auth.signers.get_resource_principals_signer()
    config = {"region": region} if region else {}
    compute = oci.core.ComputeClient(config=config, signer=signer)

    instance = compute.get_instance(standby_instance_ocid).data
    current_state = instance.lifecycle_state
    LOGGER.info("Standby instance %s is %s", standby_instance_ocid, current_state)

    if current_state == "STOPPED":
        compute.instance_action(standby_instance_ocid, "START")
        LOGGER.info("Start action sent to %s", standby_instance_ocid)
        return {
            "action": "START",
            "instance_ocid": standby_instance_ocid,
            "previous_state": current_state,
        }

    return {
        "action": "noop",
        "instance_ocid": standby_instance_ocid,
        "current_state": current_state,
    }
