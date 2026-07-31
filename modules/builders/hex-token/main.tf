# Hashing a cryptographically random ephemeral source produces a lowercase hex
# token. The default 64-character output matches `openssl rand -hex 32`.
ephemeral "random_password" "source" {
  for_each = var.tokens

  length  = 64
  special = false
}

locals {
  secret_values = {
    for name, config in var.tokens :
    name => substr(sha512(ephemeral.random_password.source[name].result), 0, config.length)
  }
}
