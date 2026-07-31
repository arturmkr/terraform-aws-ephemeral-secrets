ephemeral "random_password" "client_secret" {
  for_each = var.clients

  length      = each.value.secret_length
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

locals {
  secret_values = {
    for name, config in var.clients : name => jsonencode({
      client_id     = config.client_id
      client_secret = ephemeral.random_password.client_secret[name].result
      environment   = var.environment
    })
  }
}
