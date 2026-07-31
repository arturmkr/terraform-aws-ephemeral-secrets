output "secrets" {
  description = "Safe metadata. Generated secret values are intentionally unavailable."
  value       = module.application_secrets.metadata
}
