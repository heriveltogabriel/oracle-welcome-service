output "http_monitor_id" {
  description = "OCID of the OCI Health Checks HTTP monitor."
  value       = oci_health_checks_http_monitor.app.id
}

output "alarm_id" {
  description = "OCID of the Monitoring alarm."
  value       = oci_monitoring_alarm.health_failed.id
}

output "alarm_query" {
  description = "MQL query used by the alarm."
  value       = local.alarm_query
}

output "notification_topic_id" {
  description = "OCID of the Notifications topic."
  value       = oci_ons_notification_topic.failover.id
}

output "function_application_id" {
  description = "OCID of the OCI Functions application."
  value       = oci_functions_application.failover.id
}

output "function_id" {
  description = "OCID of the failover Function."
  value       = oci_functions_function.start_standby.id
}

output "function_subscription_id" {
  description = "OCID of the Notifications subscription that invokes the Function."
  value       = oci_ons_subscription.function.id
}

output "email_subscription_id" {
  description = "OCID of the optional email subscription, if created."
  value       = try(oci_ons_subscription.email[0].id, null)
}

output "dynamic_group_matching_rule" {
  description = "Dynamic group matching rule for the failover Function."
  value       = "ALL {resource.type = 'fnfunc', resource.id = '${oci_functions_function.start_standby.id}'}"
}

output "iam_policy_statements" {
  description = "IAM policy statements required by the failover Function."
  value       = local.identity_policy_statements
}

output "healthcheck_url" {
  description = "URL represented by the Health Check configuration."
  value       = "${lower(var.healthcheck_protocol)}://${var.healthcheck_target}:${var.healthcheck_port}${var.healthcheck_path}"
}
