# Ephemeral TLS resources keep private key material out of state and plans.
ephemeral "tls_private_key" "key" {
  for_each = var.keys

  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

locals {
  secret_values = {
    for name in keys(var.keys) : name => jsonencode({
      algorithm          = "ECDSA-P384"
      format             = "PEM"
      private_key_pem    = ephemeral.tls_private_key.key[name].private_key_pem
      public_key_openssh = ephemeral.tls_private_key.key[name].public_key_openssh
    })
  }
}
