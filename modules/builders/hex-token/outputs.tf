output "values" {
  description = "Generated hexadecimal tokens keyed by caller-defined identifier."
  value       = local.secret_values
  sensitive   = true
  ephemeral   = true
}
