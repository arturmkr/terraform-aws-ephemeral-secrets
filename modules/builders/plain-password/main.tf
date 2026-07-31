ephemeral "random_password" "password" {
  for_each = var.passwords

  length      = each.value.length
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}
