output "metadata" {
  description = "Safe metadata for every Orders API secret, keyed by secret name component."
  value = merge(
    { for name, secret in module.hex_token_secrets : name => secret.metadata },
    { for name, secret in module.username_password_secrets : name => secret.metadata },
    { for name, secret in module.tls_private_key_secrets : name => secret.metadata },
    { for name, secret in module.multi_user_document_secrets : name => secret.metadata },
  )
}
