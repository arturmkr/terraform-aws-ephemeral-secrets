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
environments/dev ─┐
                  ├── orders-api-secrets ── builders/* ── aws-secret
environments/stage┘
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
  secret_string_wo_version = var.secret_version
}
```

Regular generated resources store their results in Terraform state. Here,
generation uses ephemeral resources and the AWS write-only argument is the
boundary at which the value leaves Terraform. Outputs expose only names, ARNs,
AWS version IDs, and configured secret version numbers.

## Adding and regenerating secrets

Orders API secrets are declared in `modules/orders-api-secrets/main.tf`.
Adding another secret of an existing format means adding one catalog entry.

Every entry starts with `version = 1`. Repeated applies and metadata-only
changes keep the existing value. Incrementing the counter writes one new AWS
version without replacing the secret. Environment-specific overrides live in
`environments/dev/config.tf`:

```hcl
locals {
  # An empty map means every secret is on version 1.
  orders_api_secret_versions = {
    "shared-key" = 2 # Generate a new value only for this dev secret.
  }
}
```

`dev` and `stage` use the same Orders API secret set but have independent state,
secret names, tags, and optional version overrides.

## Repository structure

```text
bootstrap/                    S3 backend with encryption, versioning and locking
environments/dev/             deployable Terraform root
  config.tf                   dev name, tags and secret version overrides
environments/stage/           independent stage root using the same catalog
modules/orders-api-secrets/   complete Orders API secret set
modules/builders/             four value builders
modules/aws-secret/           AWS Secrets Manager writer
.github/workflows/            infrastructure bootstrap, checks and deployment
```

## GitHub Actions

Create GitHub Environments named `dev` and `stage`. Configure these values in
each environment:

- `AWS_ACCESS_KEY_ID` — secret;
- `AWS_SECRET_ACCESS_KEY` — secret;
- `AWS_REGION` — secret;
- `TF_STATE_REGION` — secret containing the S3 state bucket region;
- `TF_STATE_BUCKET` — secret containing a globally unique bucket name.

The AWS principal needs access to the state bucket and the application's
Secrets Manager path.

Each environment can point to a different AWS account, region and state bucket.
No approval is required unless an environment protection rule is enabled.

Deployment flow:

1. Run **Infra Bootstrap** once for `dev` and once for `stage`.
   The selected GitHub Environment provides that account's credentials and
   state bucket name. Bootstrap is intentionally a separate administrative
   workflow; regular pull requests and deployments assume the backend exists.
2. Pull requests validate and plan only environments affected by the changes.
   A change under `modules/` checks both `dev` and `stage`.
3. A push to `main` applies only the affected environments.
4. **Infra Deploy** can manually `apply` or `destroy` `dev`, `stage`, or `all`.

Each environment stores its state in its own bucket:

```text
dev account   → dev state bucket   → secure-secrets/dev/terraform.tfstate
stage account → stage state bucket → secure-secrets/stage/terraform.tfstate
```

Manual `destroy` is included only to clean up this sandbox after testing. A
production deployment workflow would normally disable unrestricted destroy.
Destroy keeps the backend and schedules secret deletion using AWS's seven-day
recovery window.

For local commands, use the normal AWS credential chain or an AWS profile.

## Local checks

Terraform 1.11 or newer is required.

```bash
make check
```

This runs Terraform formatting and validation for both independent roots.
