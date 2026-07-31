variable "passwords" {
  description = "Password generation settings keyed by caller-defined identifier."
  type = map(object({
    length = optional(number, 32)
  }))
  default = {}

  validation {
    condition     = alltrue([for config in values(var.passwords) : config.length >= 8])
    error_message = "Password lengths must be at least 8."
  }
}
