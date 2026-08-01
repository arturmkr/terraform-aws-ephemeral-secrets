module "application_secrets" {
  source = "../../modules/application-secrets"

  application_name = var.application_name
  environment      = var.environment
  tags             = var.tags
  value_versions   = var.value_versions
}
