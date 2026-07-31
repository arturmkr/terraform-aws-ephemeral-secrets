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

variable "hex_tokens" {
  description = "Hexadecimal shared keys and API tokens."
  type = map(object({
    description = string
    length      = optional(number, 64)
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "username_passwords" {
  description = "JSON documents containing a fixed username and generated password."
  type = map(object({
    description     = string
    username        = string
    password_length = optional(number, 32)
    tags            = optional(map(string), {})
  }))
  default = {}
}

variable "client_credentials" {
  description = "JSON documents containing client ID, generated secret, and environment."
  type = map(object({
    description   = string
    client_id     = string
    secret_length = optional(number, 40)
    tags          = optional(map(string), {})
  }))
  default = {}
}

variable "plain_passwords" {
  description = "Generated passwords stored as raw strings."
  type = map(object({
    description = string
    length      = optional(number, 32)
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "tls_private_keys" {
  description = "Ephemerally generated ECDSA P-384 private keys."
  type = map(object({
    description = string
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "multi_user_documents" {
  description = "Base64-encoded JSON documents containing usernames and bcrypt hashes."
  type = map(object({
    description = string
    usernames   = list(string)
    tags        = optional(map(string), {})
  }))
  default = {}
}
