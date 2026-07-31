variable "environment" {
  description = "Environment included in each credentials document."
  type        = string
}

variable "clients" {
  description = "Client-credentials generation settings keyed by caller-defined identifier."
  type = map(object({
    client_id     = string
    secret_length = optional(number, 40)
  }))
  default = {}

  validation {
    condition = alltrue([
      for config in values(var.clients) :
      length(trimspace(config.client_id)) > 0 && config.secret_length >= 8
    ])
    error_message = "Client IDs must be non-empty and secret lengths at least 8."
  }
}
