# OCI Health Check Failover Resource Manager Stack

This stack creates an OCI-native failover path:

```text
OCI Health Checks -> Monitoring Alarm -> Notifications Topic -> OCI Function -> START standby VM
```

Terraform creates the OCI resources. The OCI Function is the runtime action that starts the stopped standby instance.

## Important limitation

OCI Resource Manager runs Terraform, but it does not build and push Docker images for OCI Functions. This stack includes the Function source in `function/`, and Terraform expects the image to already exist in OCIR through the `function_image` variable.

## Files

- `versions.tf`: Terraform and OCI provider requirements.
- `variables.tf`: Stack inputs for Resource Manager.
- `main.tf`: Health Check, alarm, topic, Function, subscription, dynamic group, and policy.
- `outputs.tf`: OCIDs, alarm query, and IAM statements.
- `schema.yaml`: Resource Manager input form metadata.
- `function/`: Python Function that starts the standby VM.
- `scripts/build-and-push-function.sh`: Helper to build and push the Function image to OCIR.

## Build and push the Function image

Run this from a machine or Cloud Shell already logged in to OCIR.

```bash
cd oci-healthcheck-failover-resource-manager
export FUNCTION_IMAGE='vcp.ocir.io/<namespace>/failover/start-standby:1.0.0'
./scripts/build-and-push-function.sh
```

Use the same value for the Resource Manager variable `function_image`.

If the Function cannot pull the image at runtime, set `allow_faas_to_read_repos = true` in the stack variables, or create this policy manually:

```text
Allow service faas to read repos in tenancy
```

## Create the Resource Manager stack

Create a zip from this directory:

```bash
cd oci-healthcheck-failover-resource-manager
zip -r ../oci-healthcheck-failover-resource-manager.zip . -x '*.terraform*' '*.tfstate*'
```

If the Resource Manager schema form gives validation trouble, upload a zip without `schema.yaml`. Resource Manager can still read the Terraform variables directly:

```bash
./scripts/package-resource-manager.sh
```

Then in OCI Console:

1. Go to **Developer Services -> Resource Manager -> Stacks**.
2. Create a stack from **My configuration**.
3. Upload `oci-healthcheck-failover-resource-manager.zip`.
4. Fill the required variables.
5. Run **Plan**.
6. Run **Apply**.

## Required variables

- `region`: OCI region, for example `sa-saopaulo-1`.
- `tenancy_ocid`: tenancy OCID.
- `compartment_ocid`: compartment for the Health Check, alarm, topic, and Function.
- `standby_instance_ocid`: stopped VM that should be started when the alarm fires.
- `healthcheck_target`: host or IP only, for example `app.example.com`.
- `healthcheck_path`: path, for example `/health-check`.
- `function_image`: full OCIR image name.
- `function_subnet_ocid`: subnet OCID for the Functions application.

If the standby VM is in another compartment, set `compute_compartment_ocid`.

## Alarm query

The default alarm query is:

```text
HTTP.StatusCode[1m]{resourceId = "<http-monitor-ocid>"}.mean() >= 400
```

This catches HTTP responses such as 400, 500, and similar failures. The `resourceId` dimension is required so the alarm evaluates the specific Health Check monitor created by the stack. Depending on the metrics exposed in your tenancy, you may prefer a Health Checks success/availability metric instead. Use `alarm_query_override` to provide the exact MQL query you want Resource Manager to use.

After apply, check the `alarm_query` output and confirm in **Monitoring -> Alarms** that the query returns the expected stream.

## IAM behavior

By default, the stack creates:

- a dynamic group matching only the created Function OCID;
- a policy allowing that dynamic group to manage compute instances in the standby VM compartment.

The policy statement is intentionally broad enough to make the `START` action work:

```text
Allow dynamic-group <dynamic_group_name> to manage instance-family in compartment id <compute_compartment_ocid>
```

If your tenancy requires stricter IAM, set `create_identity_resources = false`, run the stack once, copy the `dynamic_group_matching_rule` and `iam_policy_statements` outputs, and create equivalent IAM resources manually.

IAM propagation can take a minute or two after apply.

## Network requirements

The Function subnet must be able to reach OCI service endpoints. Use one of these patterns:

- public subnet with egress to the internet;
- private subnet with NAT Gateway;
- private subnet with Service Gateway and routes that allow access to Oracle Services Network.

The Health Check target must be reachable from OCI Health Checks vantage points. If the target uses HTTPS by IP address, configure an appropriate Host header in `healthcheck_headers`.

## Test

After apply:

1. Confirm the email subscription if you set `notification_email`.
2. Stop the standby instance.
3. Temporarily make `/health-check` return a failing status.
4. Wait for `alarm_pending_duration`.
5. Confirm the alarm enters `FIRING`.
6. Confirm the Function starts the standby instance.

To avoid accidental failover during testing, you can temporarily point `standby_instance_ocid` to a disposable stopped VM.
