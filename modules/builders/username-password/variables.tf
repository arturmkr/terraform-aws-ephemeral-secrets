variable "credentials" {
  description = "Username/password generation settings keyed by caller-defined identifier."
  type = map(object({
    username        = string
    password_length = optional(number, 32)
  }))
  default = {}

  validation {
    condition = alltrue([
      for config in values(var.credentials) :
      length(trimspace(config.username)) > 0 && config.password_length >= 8
    ])
    error_message = "Usernames must be non-empty and password lengths at least 8."
  }
}
