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

  hex_tokens = {
    "shared-key" = {
      description = "256-bit shared key used for service-to-service authentication"
    }
  }

  username_passwords = {
    "database-credentials" = {
      description = "Database login and generated password"
      username    = "application-user"
    }
  }

  client_credentials = {
    "oauth-client" = {
      description = "OAuth client ID and generated client secret"
      client_id   = "application-client"
    }
  }

  plain_passwords = {
    "service-password" = {
      description = "Generated password consumed as a plain string"
      length      = 40
    }
  }

  tls_private_keys = {
    "service-private-key" = {
      description = "ECDSA P-384 private key and corresponding public key"
    }
  }

  multi_user_documents = {
    "application-users" = {
      description = "Base64-encoded user document containing bcrypt password hashes"
      usernames   = ["service-reader", "service-writer", "service-admin"]
    }
  }
}
