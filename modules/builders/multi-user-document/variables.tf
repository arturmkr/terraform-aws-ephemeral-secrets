variable "documents" {
  description = "Multi-user document settings keyed by caller-defined identifier."
  type = map(object({
    usernames = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for config in values(var.documents) :
      length(config.usernames) > 0 &&
      length(distinct(config.usernames)) == length(config.usernames) &&
      alltrue([for username in config.usernames : length(trimspace(username)) > 0])
    ])
    error_message = "Usernames must be non-empty and unique within each document."
  }
}
