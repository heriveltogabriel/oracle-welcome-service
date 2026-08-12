# OCI Health Check Failover Resource Manager Stack

This stack creates an OCI-native failover path:

```text
OCI Health Checks -> Monitoring Alarm -> Notifications Topic -> OCI Function -> START standby VM
```

Terraform creates the OCI resources. The OCI Function is the runtime action that starts the stopped standby instance.

## Important limitation

OCI Resource Manager runs Terraform, but it does not build and push Docker images for OCI Functions. This stack includes the Function source in `function/`, and Terraform expects the image to already exist in OCIR through the `function_image` variable.

For the complete validated walkthrough, including OCIR, Resource Manager variables, manual IAM, alarm validation, Function logs, and end-to-end testing, use `TUTORIAL.md`.

## Files

- `versions.tf`: Terraform and OCI provider requirements.
- `variables.tf`: Stack inputs for Resource Manager.
- `main.tf`: Health Check, alarm, topic, Function, subscription, and optional dynamic group/policy.
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

If the Function cannot pull the image at runtime and `create_identity_resources = false`, create this policy manually in the tenancy home region:

```text
Allow service faas to read repos in tenancy
```

## Create the Resource Manager stack

For the guided setup, use the versioned package without Resource Manager schema metadata:

```text
oci-healthcheck-failover-resource-manager-20260812-v4-no-schema.zip
```

If you need to create a fresh zip from this directory:

```bash
cd oci-healthcheck-failover-resource-manager
./scripts/package-resource-manager.sh
```

The package script excludes `schema.yaml`. This is intentional: Resource Manager can still read Terraform variables directly, and the no-schema package avoids schema form validation problems.

Then in OCI Console:

1. Go to **Developer Services -> Resource Manager -> Stacks**.
2. Create a stack from **My configuration**.
3. Upload `oci-healthcheck-failover-resource-manager-20260812-v4-no-schema.zip`.
4. Fill the required variables.
5. Run **Plan**.
6. Run **Apply**.

## Required variables

- `region`: OCI region, for example `sa-vinhedo-1`.
- `tenancy_ocid`: tenancy OCID.
- `compartment_ocid`: compartment for the Health Check, alarm, topic, and Function.
- `standby_instance_ocid`: stopped VM that should be started when the alarm fires.
- `healthcheck_target`: host or IP only, for example `app.example.com`.
- `healthcheck_path`: path, for example `/health-check`.
- `function_image`: full OCIR image name.
- `function_subnet_ocid`: subnet OCID for the Functions application.
- `create_identity_resources`: keep `false` for this workflow and create IAM manually in the tenancy home region.

If the standby VM is in another compartment, set `compute_compartment_ocid`.

## Alarm query

The default alarm query is:

```text
HTTP.StatusCode[1m]{resourceId = "<http-monitor-ocid>"}.mean() >= 400
```

This catches HTTP responses such as 400, 500, and similar failures. The `resourceId` dimension is required so the alarm evaluates the specific Health Check monitor created by the stack. Depending on the metrics exposed in your tenancy, you may prefer a Health Checks success/availability metric instead. Use `alarm_query_override` to provide the exact MQL query you want Resource Manager to use.

After apply, check the `alarm_query` output and confirm in **Monitoring -> Alarms** that the query returns the expected stream.

## IAM behavior

By default, the stack does not create IAM resources:

- `create_identity_resources = false`

This avoids OCI Identity failures when the stack runs outside the tenancy home region. Create IAM manually in the tenancy home region after apply.

Manual IAM requires two separate resources:

```text
Dynamic Group = matches the Function resource
Policy = grants that Dynamic Group permission to start the standby VM
```

Dynamic Group matching rule:

```text
ALL {resource.type = 'fnfunc', resource.id = '<function_id>'}
```

Policy statement:

```text
Allow dynamic-group dg-healthcheck-failover-fn to manage instance-family in compartment id <compute_compartment_ocid>
```

When `create_identity_resources = true`, the stack creates:

- a dynamic group matching only the created Function OCID;
- a policy allowing that dynamic group to manage compute instances in the standby VM compartment.

The policy statement is intentionally broad enough to make the `START` action work:

```text
Allow dynamic-group <dynamic_group_name> to manage instance-family in compartment id <compute_compartment_ocid>
```

For the Vinhedo flow in `TUTORIAL.md`, keep `create_identity_resources = false`, run the stack once, copy the `dynamic_group_matching_rule` and `iam_policy_statements` outputs, and create equivalent IAM resources manually in the home region.

IAM propagation can take 2 to 5 minutes after apply.

## Network requirements

The Function subnet must be able to reach OCI service endpoints. Use one of these patterns:

- public subnet with egress to the internet;
- private subnet with NAT Gateway;
- private subnet with Service Gateway and routes that allow access to Oracle Services Network.

The Health Check target must be reachable from OCI Health Checks vantage points. If the target uses HTTPS by IP address, configure an appropriate Host header in `healthcheck_headers`.

## Test

After apply:

1. Create the Dynamic Group and Policy manually in the home region.
2. Wait a few minutes for IAM propagation.
3. Test the Function directly:

```bash
export FUNCTION_ID="<function_id>"
./scripts/test-function-invoke.sh
```

4. Confirm the direct response is `action START` or `action noop`.
5. Stop the standby instance.
6. Temporarily make `/health-check` return a failing status.
7. Confirm `HTTP.StatusCode` reaches `500`.
8. Confirm the alarm enters `FIRING`.
9. Confirm the Function starts the standby instance.

To avoid accidental failover during testing, you can temporarily point `standby_instance_ocid` to a disposable stopped VM.
