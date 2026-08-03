# AWS-specific persistence boundary. This module intentionally treats the
# payload as opaque; JSON shape, encoding, hashing, and generation belong in
# provider-independent builder modules.
resource "aws_secretsmanager_secret" "this" {
  name                    = var.name
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "current" {
  secret_id                = aws_secretsmanager_secret.this.id
  secret_string_wo         = var.secret_value
  secret_string_wo_version = var.secret_version
}
