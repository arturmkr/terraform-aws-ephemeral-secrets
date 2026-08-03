locals {
  environment = "stage"

  tags = {
    Project = "secure-aws-secrets-provisioning"
  }

  # Omitted secrets start at version 1. Increment only to generate a new value.
  orders_api_secret_versions = {}
}
