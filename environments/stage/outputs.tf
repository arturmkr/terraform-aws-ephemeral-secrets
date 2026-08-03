output "secrets" {
  description = "Safe metadata. Generated secret values are intentionally unavailable."
  value       = module.orders_api_secrets.metadata
}
