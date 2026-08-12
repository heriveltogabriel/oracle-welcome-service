locals {
  compute_compartment_id = trimspace(var.compute_compartment_ocid) != "" ? var.compute_compartment_ocid : var.compartment_ocid
  compute_policy_scope   = local.compute_compartment_id == var.tenancy_ocid ? "tenancy" : "compartment id ${local.compute_compartment_id}"

  default_alarm_query = "HTTP.StatusCode[1m]{resourceId = \"${oci_health_checks_http_monitor.app.id}\"}.mean() >= ${var.unhealthy_http_status_code_threshold}"
  alarm_query         = trimspace(var.alarm_query_override) != "" ? var.alarm_query_override : local.default_alarm_query

  alarm_repeat_notification_duration = trimspace(var.alarm_repeat_notification_duration) != "" ? var.alarm_repeat_notification_duration : null
  raw_healthcheck_vantage_point_names = trimspace(var.healthcheck_vantage_point_names)
  healthcheck_vantage_point_names = (
    local.raw_healthcheck_vantage_point_names == "" ? [] :
    can(tolist(jsondecode(local.raw_healthcheck_vantage_point_names))) ? [
      for name in tolist(jsondecode(local.raw_healthcheck_vantage_point_names)) : tostring(name)
    ] :
    [
      for name in split(",", local.raw_healthcheck_vantage_point_names) : trimspace(name)
      if trimspace(name) != ""
    ]
  )
  raw_function_subnet_ocids = trimspace(var.function_subnet_ocids)
  function_subnet_ocids = (
    local.raw_function_subnet_ocids == "" ? [] :
    can(tolist(jsondecode(local.raw_function_subnet_ocids))) ? [
      for ocid in tolist(jsondecode(local.raw_function_subnet_ocids)) : tostring(ocid)
    ] :
    [
      for ocid in split(",", local.raw_function_subnet_ocids) : trimspace(ocid)
      if trimspace(ocid) != ""
    ]
  )
  raw_function_nsg_ocids = trimspace(var.function_nsg_ocids)
  function_nsg_ocids = (
    local.raw_function_nsg_ocids == "" ? [] :
    can(tolist(jsondecode(local.raw_function_nsg_ocids))) ? [
      for ocid in tolist(jsondecode(local.raw_function_nsg_ocids)) : tostring(ocid)
    ] :
    [
      for ocid in split(",", local.raw_function_nsg_ocids) : trimspace(ocid)
      if trimspace(ocid) != ""
    ]
  )

  function_config = {
    OCI_REGION            = var.region
    STANDBY_INSTANCE_OCID = var.standby_instance_ocid
    EXPECTED_ALARM_OCID   = oci_monitoring_alarm.health_failed.id
    REQUIRE_FIRING_STATE  = "true"
  }

  function_subnet_ids = distinct(compact(concat([trimspace(var.function_subnet_ocid)], local.function_subnet_ocids)))

  identity_policy_statements = concat(
    [
      "Allow dynamic-group ${var.dynamic_group_name} to manage instance-family in ${local.compute_policy_scope}"
    ],
    var.allow_faas_to_read_repos ? ["Allow service faas to read repos in tenancy"] : []
  )
}

resource "oci_health_checks_http_monitor" "app" {
  compartment_id      = var.compartment_ocid
  display_name        = "${var.name_prefix}-http-monitor"
  interval_in_seconds = var.healthcheck_interval_in_seconds
  is_enabled          = true
  method              = upper(var.healthcheck_method)
  path                = var.healthcheck_path
  port                = var.healthcheck_port
  protocol            = upper(var.healthcheck_protocol)
  targets             = [var.healthcheck_target]
  timeout_in_seconds  = var.healthcheck_timeout_in_seconds

  headers             = var.healthcheck_headers
  vantage_point_names = length(local.healthcheck_vantage_point_names) > 0 ? local.healthcheck_vantage_point_names : null
  freeform_tags       = var.freeform_tags
}

resource "oci_ons_notification_topic" "failover" {
  compartment_id = var.compartment_ocid
  name           = "${var.name_prefix}-topic"
  description    = "Alarm destination for ${var.name_prefix} health-check failover."
  freeform_tags  = var.freeform_tags
}

resource "oci_monitoring_alarm" "health_failed" {
  compartment_id               = var.compartment_ocid
  destinations                 = [oci_ons_notification_topic.failover.id]
  display_name                 = "${var.name_prefix}-health-failed"
  is_enabled                   = true
  metric_compartment_id        = var.compartment_ocid
  namespace                    = var.alarm_namespace
  query                        = local.alarm_query
  severity                     = var.alarm_severity
  body                         = "Health Check failed for ${var.healthcheck_target}${var.healthcheck_path}. Starting standby instance ${var.standby_instance_ocid}."
  message_format               = "RAW"
  pending_duration             = var.alarm_pending_duration
  repeat_notification_duration = local.alarm_repeat_notification_duration

  is_notifications_per_metric_dimension_enabled = false
  freeform_tags                                  = var.freeform_tags
}

resource "oci_functions_application" "failover" {
  compartment_id             = var.compartment_ocid
  display_name               = "${var.name_prefix}-fn-app"
  subnet_ids                 = local.function_subnet_ids
  network_security_group_ids = length(local.function_nsg_ocids) > 0 ? local.function_nsg_ocids : null
  shape                      = var.function_shape
  freeform_tags              = var.freeform_tags

  lifecycle {
    precondition {
      condition     = length(local.function_subnet_ids) > 0
      error_message = "Set function_subnet_ocid to the OCID of the subnet where the OCI Functions application will run."
    }
  }
}

resource "oci_functions_function" "start_standby" {
  application_id     = oci_functions_application.failover.id
  display_name       = "${var.name_prefix}-start-standby"
  image              = var.function_image
  memory_in_mbs      = var.function_memory_in_mbs
  timeout_in_seconds = var.function_timeout_in_seconds
  config             = local.function_config
  freeform_tags      = var.freeform_tags
}

resource "oci_ons_subscription" "function" {
  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.failover.id
  protocol       = "ORACLE_FUNCTIONS"
  endpoint       = oci_functions_function.start_standby.id
  freeform_tags  = var.freeform_tags
}

resource "oci_ons_subscription" "email" {
  count = trimspace(var.notification_email) != "" ? 1 : 0

  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.failover.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_dynamic_group" "function" {
  count = var.create_identity_resources ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = var.dynamic_group_name
  description    = "Matches the health-check failover Function."
  matching_rule  = "ALL {resource.type = 'fnfunc', resource.id = '${oci_functions_function.start_standby.id}'}"
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_policy" "function" {
  count = var.create_identity_resources ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = var.policy_name
  description    = "Allows the health-check failover Function to start the standby compute instance."
  statements     = local.identity_policy_statements
  freeform_tags  = var.freeform_tags

  depends_on = [oci_identity_dynamic_group.function]
}
