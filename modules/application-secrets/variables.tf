variable "application_name" {
  description = "Application namespace used in secret names and tags."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9/_+=.@-]+$", var.application_name))
    error_message = "application_name contains characters unsupported by AWS Secrets Manager names."
  }
}

variable "environment" {
  description = "Deployment environment used in secret names and payloads."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9/_+=.@-]+$", var.environment))
    error_message = "environment contains characters unsupported by AWS Secrets Manager names."
  }
}

variable "tags" {
  description = "Common tags applied to every secret."
  type        = map(string)
  default     = {}
}

variable "value_versions" {
  description = "Rotation counters keyed by secret key. Omitted secrets start at version 1."
  type        = map(number)
  default     = {}

  validation {
    condition     = alltrue([for version in values(var.value_versions) : version >= 1 && floor(version) == version])
    error_message = "Every value version must be a positive integer."
  }
}
