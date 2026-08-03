variable "environment" {
  description = "Deployment environment used in Orders API secret names."
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

variable "versions" {
  description = "Versions keyed by secret name. Increment a version to generate a new value."
  type        = map(number)
  default     = {}

  validation {
    condition     = alltrue([for version in values(var.versions) : version >= 1 && floor(version) == version])
    error_message = "Every secret version must be a positive integer."
  }
}
