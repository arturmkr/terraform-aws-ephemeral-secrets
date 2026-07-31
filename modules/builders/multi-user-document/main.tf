locals {
  users = length(var.documents) == 0 ? {} : merge([
    for document_name, config in var.documents : {
      for username in config.usernames :
      "${document_name}:${sha256(username)}" => {
        document_name = document_name
        username      = username
      }
    }
  ]...)
}

ephemeral "random_password" "password" {
  for_each = local.users

  length      = 32
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

locals {
  # The consumer expects one Base64-encoded document. Passwords are converted
  # to one-way bcrypt hashes before the JSON document is encoded.
  secret_values = {
    for document_name, config in var.documents : document_name => base64encode(jsonencode({
      hash_algorithm = "bcrypt"
      users = [
        for username in config.usernames : {
          username      = username
          password_hash = ephemeral.random_password.password["${document_name}:${sha256(username)}"].bcrypt_hash
        }
      ]
    }))
  }
}
