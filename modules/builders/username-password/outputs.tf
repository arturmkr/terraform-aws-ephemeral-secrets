output "values" {
  description = "Generated username/password JSON documents keyed by caller-defined identifier."
  value       = local.secret_values
  sensitive   = true
  ephemeral   = true
}
