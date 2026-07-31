variable "keys" {
  description = "Private keys to generate, keyed by caller-defined identifier."
  type        = map(object({}))
  default     = {}
}
