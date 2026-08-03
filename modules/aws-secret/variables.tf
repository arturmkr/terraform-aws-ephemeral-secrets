variable "name" {
  description = "Name of the AWS Secrets Manager secret."
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty."
  }
}

variable "description" {
  description = "Human-readable description of the secret."
  type        = string
}

variable "tags" {
  description = "Tags applied to the AWS secret metadata resource."
  type        = map(string)
  default     = {}
}

variable "secret_value" {
  description = "Final opaque secret payload. It is accepted only as an ephemeral value."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "secret_version" {
  description = "Non-secret version number. Increment to write a newly generated secret value."
  type        = number

  validation {
    condition     = var.secret_version >= 1 && floor(var.secret_version) == var.secret_version
    error_message = "secret_version must be a positive integer."
  }
}

variable "recovery_window_in_days" {
  description = "Number of days AWS retains a deleted secret for recovery."
  type        = number
  default     = 7

  validation {
    condition     = var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30
    error_message = "recovery_window_in_days must be between 7 and 30."
  }
}
