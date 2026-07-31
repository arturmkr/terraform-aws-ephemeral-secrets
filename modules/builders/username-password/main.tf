ephemeral "random_password" "password" {
  for_each = var.credentials

  length      = each.value.password_length
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

locals {
  secret_values = {
    for name, config in var.credentials : name => jsonencode({
      username = config.username
      password = ephemeral.random_password.password[name].result
    })
  }
}
