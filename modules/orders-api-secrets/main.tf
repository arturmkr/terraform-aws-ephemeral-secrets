locals {
  name_prefix = "orders-api/${var.environment}"
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Service     = "orders-api"
  })

  # Orders API secret catalog. Add another entry to the matching collection
  # to provision another secret of that format.
  hex_tokens = {
    "shared-key" = {
      description = "256-bit shared key used for service-to-service authentication"
      length      = 64
      tags        = {}
      version     = lookup(var.versions, "shared-key", 1)
    }
  }
  username_passwords = {
    "database-credentials-user" = {
      description     = "Database application user login and generated password"
      username        = "application-user"
      password_length = 32
      tags            = {}
      version         = lookup(var.versions, "database-credentials-user", 1)
    }
    "database-credentials-admin" = {
      description     = "Database application administrator login and generated password"
      username        = "application-admin"
      password_length = 32
      tags            = {}
      version         = lookup(var.versions, "database-credentials-admin", 1)
    }
  }
  tls_private_keys = {
    "service-private-key" = {
      description = "ECDSA P-384 private key and corresponding public key"
      tags        = {}
      version     = lookup(var.versions, "service-private-key", 1)
    }
  }
  multi_user_documents = {
    "application-users" = {
      description = "Base64-encoded user document containing bcrypt password hashes"
      usernames   = ["service-reader", "service-writer", "service-admin"]
      tags        = {}
      version     = lookup(var.versions, "application-users", 1)
    }
  }

  secret_names = concat(
    keys(local.hex_tokens),
    keys(local.username_passwords),
    keys(local.tls_private_keys),
    keys(local.multi_user_documents),
  )
}

check "unique_secret_names" {
  assert {
    condition     = length(local.secret_names) == length(distinct(local.secret_names))
    error_message = "Secret keys must be unique across all format collections."
  }
}

check "known_versions" {
  assert {
    condition     = alltrue([for name in keys(var.versions) : contains(local.secret_names, name)])
    error_message = "versions contains a key that is not declared in the Orders API secret set."
  }
}

module "hex_tokens" {
  source = "../builders/hex-token"

  tokens = {
    for name, config in local.hex_tokens : name => {
      length = config.length
    }
  }
}

module "username_passwords" {
  source = "../builders/username-password"

  credentials = {
    for name, config in local.username_passwords : name => {
      username        = config.username
      password_length = config.password_length
    }
  }
}

module "tls_private_keys" {
  source = "../builders/tls-private-key"

  keys = { for name in keys(local.tls_private_keys) : name => {} }
}

module "multi_user_documents" {
  source = "../builders/multi-user-document"

  documents = {
    for name, config in local.multi_user_documents : name => {
      usernames = config.usernames
    }
  }
}

# AWS persistence lives in this composition layer. Builders above can be reused
# unchanged with a different cloud-specific writer.
module "hex_token_secrets" {
  for_each = local.hex_tokens
  source   = "../aws-secret"

  name           = "${local.name_prefix}/${each.key}"
  description    = each.value.description
  tags           = merge(local.common_tags, each.value.tags, { SecretFormat = "hex-token" })
  secret_value   = module.hex_tokens.values[each.key]
  secret_version = each.value.version
}

module "username_password_secrets" {
  for_each = local.username_passwords
  source   = "../aws-secret"

  name           = "${local.name_prefix}/${each.key}"
  description    = each.value.description
  tags           = merge(local.common_tags, each.value.tags, { SecretFormat = "username-password" })
  secret_value   = module.username_passwords.values[each.key]
  secret_version = each.value.version
}

module "tls_private_key_secrets" {
  for_each = local.tls_private_keys
  source   = "../aws-secret"

  name           = "${local.name_prefix}/${each.key}"
  description    = each.value.description
  tags           = merge(local.common_tags, each.value.tags, { SecretFormat = "tls-private-key" })
  secret_value   = module.tls_private_keys.values[each.key]
  secret_version = each.value.version
}

module "multi_user_document_secrets" {
  for_each = local.multi_user_documents
  source   = "../aws-secret"

  name           = "${local.name_prefix}/${each.key}"
  description    = each.value.description
  tags           = merge(local.common_tags, each.value.tags, { SecretFormat = "base64-multi-user-document" })
  secret_value   = module.multi_user_documents.values[each.key]
  secret_version = each.value.version
}
