output "state_bucket_name" {
  description = "S3 bucket name to place in environments/dev/backend.hcl."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "backend_region" {
  description = "AWS region to place in environments/dev/backend.hcl."
  value       = var.aws_region
}
