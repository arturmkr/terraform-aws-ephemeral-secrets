output "metadata" {
  description = "Safe secret metadata. No secret value is exposed."
  value = {
    arn        = aws_secretsmanager_secret.this.arn
    name       = aws_secretsmanager_secret.this.name
    version_id = aws_secretsmanager_secret_version.current.version_id
    version    = var.secret_version
  }
}
