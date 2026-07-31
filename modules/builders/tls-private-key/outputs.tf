output "values" {
  description = "Generated private-key JSON documents keyed by caller-defined identifier."
  value       = local.secret_values
  sensitive   = true
  ephemeral   = true
}
