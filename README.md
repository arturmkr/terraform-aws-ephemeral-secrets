# Secure AWS Secrets Provisioning with Terraform

Generate application secrets and write them to AWS Secrets Manager without
persisting secret values in Terraform state or saved plans.

## Context

This repository is a sanitized implementation based on a real platform
engineering task. Terraform provisioned dozens of Secrets Manager entries for
an application, but their values were populated manually in every environment.
That process was slow and error-prone: a secret could be missing, use the wrong
format, or differ between environments.

The solution defines the application's secret catalog once, generates every
value during provisioning, and writes it directly to Secrets Manager.

## Design

```text
environments/dev
    └── application-secrets       complete application secret catalog
            ├── builders/*        generate values by format
            └── aws-secret        writes an opaque value to AWS
```

The example catalog contains four formats taken from the original use case:

- hexadecimal shared key;
- username/password JSON;
- TLS private key;
- Base64-encoded multi-user credentials with bcrypt password hashes.

Builders contain no AWS dependency. The small `aws-secret` module receives an
opaque ephemeral value and writes it using `secret_string_wo`:

```hcl
resource "aws_secretsmanager_secret_version" "current" {
  secret_id                = aws_secretsmanager_secret.this.id
  secret_string_wo         = var.secret_value
  secret_string_wo_version = var.value_version
}
```

Regular generated resources store their results in Terraform state. Here,
generation uses ephemeral resources and the AWS write-only argument is the
boundary at which the value leaves Terraform. Outputs expose only names, ARNs,
AWS version IDs, and non-secret rotation counters.

## Adding and rotating secrets

Application secrets are declared in `modules/application-secrets/main.tf`.
Adding another secret of an existing format means adding one catalog entry.

Every entry starts with `value_version = 1`. Repeated applies and metadata-only
changes keep the existing value. Incrementing the counter writes one new AWS
version without replacing the secret:

```hcl
value_versions = {
  "shared-key" = 2
}
```

## Repository structure

```text
bootstrap/                    S3 backend with encryption, versioning and locking
environments/dev/             deployable Terraform root
modules/application-secrets/  application secret catalog
modules/builders/             four value builders
modules/aws-secret/           AWS Secrets Manager writer
.github/workflows/            bootstrap, pull request and apply/destroy
```

## GitHub Actions

Configure these GitHub Actions secrets:

- `AWS_ACCESS_KEY_ID`;
- `AWS_SECRET_ACCESS_KEY`.

Configure these repository variables:

- `AWS_REGION`;
- `TF_STATE_BUCKET` — globally unique S3 bucket name;
- `TF_STATE_KEY` — for example `orders-api/dev/terraform.tfstate`;
- `APPLICATION_NAME` — for example `orders-api`.

The AWS principal needs access to the state bucket and the application's
Secrets Manager path.

Deployment flow:

1. Run **Bootstrap Terraform backend** once to create the S3 backend.
2. Pull requests run `fmt`, `validate`, and a remote `plan`.
3. A push to `main` creates and applies a fresh plan.
4. **Terraform infrastructure** can be started manually with `apply` or
   `destroy`.

Destroy keeps the backend and schedules secret deletion using AWS's seven-day
recovery window.

For local commands, use the normal AWS credential chain or an AWS profile.

## Local checks

Terraform 1.11 or newer is required.

```bash
make check
```

This runs Terraform formatting and validation for both independent roots.
