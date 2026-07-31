variable "tokens" {
  description = "Hex token generation settings keyed by caller-defined identifier."
  type = map(object({
    length = optional(number, 64)
  }))
  default = {}

  validation {
    condition = alltrue([
      for config in values(var.tokens) :
      config.length >= 2 && config.length <= 128 && config.length % 2 == 0
    ])
    error_message = "Token lengths must be even numbers from 2 to 128."
  }
}
