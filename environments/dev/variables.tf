variable "aws_region" {
  description = "AWS region in which to create the secrets."
  type        = string
  default     = "eu-central-1"
}

variable "application_name" {
  description = "Application namespace for secret names and tags."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9/_+=.@-]+$", var.application_name))
    error_message = "application_name contains characters unsupported by AWS Secrets Manager names."
  }
}

variable "environment" {
  description = "Environment namespace for secret names and generated documents."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[A-Za-z0-9/_+=.@-]+$", var.environment))
    error_message = "environment contains characters unsupported by AWS Secrets Manager names."
  }
}

variable "tags" {
  description = "Additional tags applied to every secret."
  type        = map(string)
  default = {
    Project = "secure-aws-secrets-provisioning"
  }
}

variable "value_versions" {
  description = "Rotation counters keyed by catalog name. Omitted secrets start at version 1."
  type        = map(number)
  default     = {}

  validation {
    condition     = alltrue([for version in values(var.value_versions) : version >= 1 && floor(version) == version])
    error_message = "Every value version must be a positive integer."
  }
}
