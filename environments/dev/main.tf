locals {
  effective_tags = merge(
    var.tags,
    var.verification_tag == null ? {} : { Verification = var.verification_tag },
  )
}

# This is the application-facing catalog. Add another entry to an existing
# collection to provision another secret of that format.
module "application_secrets" {
  source = "../../modules/application-secrets"

  application_name = var.application_name
  environment      = var.environment
  tags             = local.effective_tags
  value_versions   = var.value_versions
}
