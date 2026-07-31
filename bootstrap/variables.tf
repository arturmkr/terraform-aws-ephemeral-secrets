variable "aws_region" {
  description = "AWS region in which to create the Terraform state bucket."
  type        = string
  default     = "eu-central-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state."
  type        = string

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63
    error_message = "state_bucket_name must be between 3 and 63 characters."
  }
}

variable "tags" {
  description = "Tags applied to the backend bucket."
  type        = map(string)
  default = {
    Project   = "secure-aws-secrets-provisioning"
    ManagedBy = "Terraform"
  }
}
