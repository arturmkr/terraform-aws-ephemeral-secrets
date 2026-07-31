output "values" {
  description = "Generated client-credentials JSON documents keyed by caller-defined identifier."
  value       = local.secret_values
  sensitive   = true
  ephemeral   = true
}
