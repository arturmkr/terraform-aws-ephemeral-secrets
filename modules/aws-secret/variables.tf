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

variable "value_version" {
  description = "Non-secret rotation counter. Increment to write a newly generated version."
  type        = number

  validation {
    condition     = var.value_version >= 1 && floor(var.value_version) == var.value_version
    error_message = "value_version must be a positive integer."
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
