module "orders_api_secrets" {
  source = "../../modules/orders-api-secrets"

  environment = local.environment
  tags        = local.tags
  versions    = local.orders_api_secret_versions
}
