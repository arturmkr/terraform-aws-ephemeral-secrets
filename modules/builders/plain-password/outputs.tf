output "values" {
  description = "Generated passwords keyed by caller-defined identifier."
  value = {
    for name in keys(var.passwords) : name => ephemeral.random_password.password[name].result
  }
  sensitive = true
  ephemeral = true
}
