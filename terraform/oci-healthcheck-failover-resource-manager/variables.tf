variable "region" {
  description = "OCI region where the Health Check, alarm, topic, and Function will be created. Example: sa-saopaulo-1."
  type        = string
}

variable "tenancy_ocid" {
  description = "Tenancy OCID. Required when create_identity_resources is true, because dynamic groups are tenancy-level IAM resources."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID where the Health Check, alarm, topic, Function application, and Function will be created."
  type        = string
}

variable "compute_compartment_ocid" {
  description = "Compartment OCID where the standby instance lives. Leave empty to use compartment_ocid."
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Short unique prefix for created OCI resources. Keep letters, numbers, and hyphens only."
  type        = string
  default     = "healthcheck-failover"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{2,50}$", var.name_prefix))
    error_message = "name_prefix must start with a letter and contain 3-51 letters, numbers, or hyphens."
  }
}

variable "standby_instance_ocid" {
  description = "OCID of the stopped standby VM instance that the Function will start."
  type        = string
}

variable "healthcheck_target" {
  description = "Hostname or public IP to probe. Do not include protocol or path. Example: app.example.com."
  type        = string
}

variable "healthcheck_path" {
  description = "HTTP path to probe on the target."
  type        = string
  default     = "/health-check"

  validation {
    condition     = startswith(var.healthcheck_path, "/")
    error_message = "healthcheck_path must start with '/'."
  }
}

variable "healthcheck_protocol" {
  description = "HTTP monitor protocol."
  type        = string
  default     = "HTTPS"

  validation {
    condition     = contains(["HTTP", "HTTPS"], upper(var.healthcheck_protocol))
    error_message = "healthcheck_protocol must be HTTP or HTTPS."
  }
}

variable "healthcheck_port" {
  description = "Port to probe. Use 443 for HTTPS or 80 for HTTP unless your application uses another port."
  type        = number
  default     = 443
}

variable "healthcheck_method" {
  description = "HTTP method used by the probe."
  type        = string
  default     = "GET"
}

variable "healthcheck_interval_in_seconds" {
  description = "Probe interval. OCI Health Checks supports 10, 30, or 60 seconds."
  type        = number
  default     = 60

  validation {
    condition     = contains([10, 30, 60], var.healthcheck_interval_in_seconds)
    error_message = "healthcheck_interval_in_seconds must be 10, 30, or 60."
  }
}

variable "healthcheck_timeout_in_seconds" {
  description = "Probe timeout. Must be less than or equal to the interval. OCI supports 10, 20, 30, or 60 seconds."
  type        = number
  default     = 10

  validation {
    condition     = contains([10, 20, 30, 60], var.healthcheck_timeout_in_seconds)
    error_message = "healthcheck_timeout_in_seconds must be 10, 20, 30, or 60."
  }
}

variable "healthcheck_headers" {
  description = "Optional HTTP headers for the Health Check. Authorization is not supported by OCI Health Checks."
  type        = map(string)
  default     = {}
}

variable "healthcheck_vantage_point_names" {
  description = "Optional OCI Health Checks vantage point names. Leave empty to let OCI select them automatically."
  type        = list(string)
  default     = []
}

variable "alarm_namespace" {
  description = "Monitoring namespace used by OCI Health Checks."
  type        = string
  default     = "oci_healthchecks"
}

variable "alarm_query_override" {
  description = "Optional complete MQL query for the alarm. Leave empty to use the default HTTP.StatusCode query with the Health Check resourceId dimension."
  type        = string
  default     = ""
}

variable "unhealthy_http_status_code_threshold" {
  description = "Default alarm threshold. Used only when alarm_query_override is empty."
  type        = number
  default     = 400
}

variable "alarm_pending_duration" {
  description = "ISO-8601 duration that the alarm condition must persist before FIRING. Example: PT3M."
  type        = string
  default     = "PT1M"
}

variable "alarm_repeat_notification_duration" {
  description = "How often to resend notifications while the alarm remains FIRING. Example: PT30M. Empty disables repeats."
  type        = string
  default     = "PT30M"
}

variable "alarm_severity" {
  description = "Monitoring alarm severity."
  type        = string
  default     = "CRITICAL"
}

variable "function_subnet_ocid" {
  description = "Subnet OCID where the OCI Functions application will run. The subnet needs egress to OCI service endpoints."
  type        = string

  validation {
    condition     = startswith(var.function_subnet_ocid, "ocid1.subnet.")
    error_message = "function_subnet_ocid must be a valid subnet OCID starting with ocid1.subnet."
  }
}

variable "function_subnet_ocids" {
  description = "Optional additional subnet OCIDs where the OCI Functions application will run. Leave empty unless you need multiple subnets."
  type        = list(string)
  default     = []
}

variable "function_nsg_ocids" {
  description = "Optional Network Security Group OCIDs for the OCI Functions application."
  type        = list(string)
  default     = []
}

variable "function_image" {
  description = "Fully qualified OCIR image for the failover Function. Example for Vinhedo: vcp.ocir.io/<namespace>/failover/start-standby:1.0.0."
  type        = string

  validation {
    condition     = length(trimspace(var.function_image)) > 0
    error_message = "function_image is required. Build and push the image from the function/ directory before applying the stack."
  }
}

variable "function_memory_in_mbs" {
  description = "Memory for the OCI Function."
  type        = number
  default     = 256
}

variable "function_timeout_in_seconds" {
  description = "Execution timeout for the OCI Function."
  type        = number
  default     = 120
}

variable "function_shape" {
  description = "OCI Functions application shape."
  type        = string
  default     = "GENERIC_X86"

  validation {
    condition     = contains(["GENERIC_X86", "GENERIC_ARM", "GENERIC_X86_ARM"], var.function_shape)
    error_message = "function_shape must be GENERIC_X86, GENERIC_ARM, or GENERIC_X86_ARM."
  }
}

variable "create_identity_resources" {
  description = "Create the dynamic group and policy that allow the Function to start the standby VM. Keep false when running the stack outside the tenancy home region; create IAM manually in the home region."
  type        = bool
  default     = false
}

variable "dynamic_group_name" {
  description = "Name for the dynamic group created for the Function."
  type        = string
  default     = "dg-healthcheck-failover-fn"
}

variable "policy_name" {
  description = "Name for the IAM policy created for the Function."
  type        = string
  default     = "policy-healthcheck-failover-fn"
}

variable "allow_faas_to_read_repos" {
  description = "Also create a tenancy policy statement allowing the OCI Functions service to read OCIR repositories. Enable if Function image pulls fail."
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "Optional email address to also receive alarm notifications. The email subscription must be confirmed."
  type        = string
  default     = ""
}

variable "freeform_tags" {
  description = "Free-form tags applied to supported resources."
  type        = map(string)
  default = {
    managed-by = "terraform"
    purpose    = "healthcheck-failover"
  }
}
