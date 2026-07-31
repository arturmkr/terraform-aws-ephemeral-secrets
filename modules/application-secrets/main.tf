locals {
  name_prefix = "${var.application_name}/${var.environment}"
  common_tags = merge(var.tags, {
    Application = var.application_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  secret_names = concat(
    keys(var.hex_tokens),
    keys(var.username_passwords),
    keys(var.client_credentials),
    keys(var.plain_passwords),
    keys(var.tls_private_keys),
    keys(var.multi_user_documents),
  )

  # Every secret starts at version 1. Only rotated secrets need an entry in
  # value_versions, so adding a new secret remains a single catalog entry.
  hex_tokens = {
    for name, config in var.hex_tokens :
    name => merge(config, { value_version = lookup(var.value_versions, name, 1) })
  }
  username_passwords = {
    for name, config in var.username_passwords :
    name => merge(config, { value_version = lookup(var.value_versions, name, 1) })
  }
  client_credentials = {
    for name, config in var.client_credentials :
    name => merge(config, { value_version = lookup(var.value_versions, name, 1) })
  }
  plain_passwords = {
    for name, config in var.plain_passwords :
    name => merge(config, { value_version = lookup(var.value_versions, name, 1) })
  }
  tls_private_keys = {
    for name, config in var.tls_private_keys :
    name => merge(config, { value_version = lookup(var.value_versions, name, 1) })
  }
  multi_user_documents = {
    for name, config in var.multi_user_documents :
    name => merge(config, { value_version = lookup(var.value_versions, name, 1) })
  }
}

check "unique_secret_names" {
  assert {
    condition     = length(local.secret_names) == length(distinct(local.secret_names))
    error_message = "Secret keys must be unique across all format collections."
  }
}

check "known_value_versions" {
  assert {
    condition     = alltrue([for name in keys(var.value_versions) : contains(local.secret_names, name)])
    error_message = "value_versions contains a key that is not declared in a secret collection."
  }
}

module "hex_tokens" {
  source = "../builders/hex-token"

  tokens = {
    for name, config in var.hex_tokens : name => {
      length = config.length
    }
  }
}

module "username_passwords" {
  source = "../builders/username-password"

  credentials = {
    for name, config in var.username_passwords : name => {
      username        = config.username
      password_length = config.password_length
    }
  }
}

module "client_credentials" {
  source = "../builders/client-credentials"

  environment = var.environment
  clients = {
    for name, config in var.client_credentials : name => {
      client_id     = config.client_id
      secret_length = config.secret_length
    }
  }
}

module "plain_passwords" {
  source = "../builders/plain-password"

  passwords = {
    for name, config in var.plain_passwords : name => {
      length = config.length
    }
  }
}

module "tls_private_keys" {
  source = "../builders/tls-private-key"

  keys = { for name in keys(var.tls_private_keys) : name => {} }
}

module "multi_user_documents" {
  source = "../builders/multi-user-document"

  documents = {
    for name, config in var.multi_user_documents : name => {
      usernames = config.usernames
    }
  }
}

# AWS persistence lives in this composition layer. Builders above can be reused
# unchanged with a different cloud-specific writer.
module "hex_token_secrets" {
  for_each = local.hex_tokens
  source   = "../aws-secret"

  name          = "${local.name_prefix}/${each.key}"
  description   = each.value.description
  tags          = merge(local.common_tags, each.value.tags, { SecretFormat = "hex-token" })
  secret_value  = module.hex_tokens.values[each.key]
  value_version = each.value.value_version
}

module "username_password_secrets" {
  for_each = local.username_passwords
  source   = "../aws-secret"

  name          = "${local.name_prefix}/${each.key}"
  description   = each.value.description
  tags          = merge(local.common_tags, each.value.tags, { SecretFormat = "username-password" })
  secret_value  = module.username_passwords.values[each.key]
  value_version = each.value.value_version
}

module "client_credential_secrets" {
  for_each = local.client_credentials
  source   = "../aws-secret"

  name          = "${local.name_prefix}/${each.key}"
  description   = each.value.description
  tags          = merge(local.common_tags, each.value.tags, { SecretFormat = "client-credentials" })
  secret_value  = module.client_credentials.values[each.key]
  value_version = each.value.value_version
}

module "plain_password_secrets" {
  for_each = local.plain_passwords
  source   = "../aws-secret"

  name          = "${local.name_prefix}/${each.key}"
  description   = each.value.description
  tags          = merge(local.common_tags, each.value.tags, { SecretFormat = "plain-password" })
  secret_value  = module.plain_passwords.values[each.key]
  value_version = each.value.value_version
}

module "tls_private_key_secrets" {
  for_each = local.tls_private_keys
  source   = "../aws-secret"

  name          = "${local.name_prefix}/${each.key}"
  description   = each.value.description
  tags          = merge(local.common_tags, each.value.tags, { SecretFormat = "tls-private-key" })
  secret_value  = module.tls_private_keys.values[each.key]
  value_version = each.value.value_version
}

module "multi_user_document_secrets" {
  for_each = local.multi_user_documents
  source   = "../aws-secret"

  name          = "${local.name_prefix}/${each.key}"
  description   = each.value.description
  tags          = merge(local.common_tags, each.value.tags, { SecretFormat = "base64-multi-user-document" })
  secret_value  = module.multi_user_documents.values[each.key]
  value_version = each.value.value_version
}
