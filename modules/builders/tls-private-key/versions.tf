terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.3"
    }
  }
}
