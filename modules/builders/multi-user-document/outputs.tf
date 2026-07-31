output "values" {
  description = "Generated Base64 multi-user documents keyed by caller-defined identifier."
  value       = local.secret_values
  sensitive   = true
  ephemeral   = true
}
