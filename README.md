# Secure AWS Secrets Provisioning with Terraform

Reusable Terraform for generating application secrets and writing them to AWS
Secrets Manager without storing secret values in Terraform state or saved plan
files. The project demonstrates Terraform ephemeral resources, AWS provider
write-only attributes, S3 remote state, native state locking, and explicit
version-based secret rotation.

## What it does

The example provisions an application secret catalog containing:

- a hexadecimal shared key;
- username/password JSON;
- client credentials JSON;
- a plain generated password;
- an ephemeral TLS private key;
- a Base64-encoded multi-user document with bcrypt password hashes.

Generated values are never exposed through Terraform outputs. Outputs contain
only secret names, ARNs, AWS version IDs, and rotation counters.

## Architecture

```text
environments/dev
    └── application-secrets       application catalog
            ├── builders/*        provider-independent value generation
            └── aws-secret        AWS Secrets Manager writer
                    └── AWS Secrets Manager
```

Builders know how to create a value but know nothing about AWS. The
`aws-secret` module treats the value as opaque and only manages the Secrets
Manager secret and its current version.

## Repository structure

```text
bootstrap/                    Creates the S3 Terraform backend
environments/dev/             Deployable dev Terraform root
modules/application-secrets/  Complete application secret catalog
modules/builders/             Reusable provider-independent builders
modules/aws-secret/           Low-level AWS Secrets Manager writer
scripts/                      Security and lifecycle tests
.github/workflows/            Bootstrap, pull-request, and infrastructure jobs
```

## Why values do not enter state

Regular `random_password` and `tls_private_key` resources persist generated
values in Terraform state. Marking their outputs as sensitive only hides CLI
display; it does not remove the values from state.

This project instead uses:

- `ephemeral` generators for transient values;
- ephemeral, sensitive module inputs and outputs;
- `secret_string_wo` to write the value without persisting it;
- `secret_string_wo_version` as the durable rotation trigger.

The low-level writer is intentionally small:

```hcl
resource "aws_secretsmanager_secret_version" "current" {
  secret_id                = aws_secretsmanager_secret.this.id
  secret_string_wo         = var.secret_value
  secret_string_wo_version = var.value_version
}
```

## Application secret catalog

All secrets belonging to the example application are declared in
`modules/application-secrets/main.tf`. To add another secret of an existing
format, add one entry to the matching collection. For example:

```hcl
hex_tokens = {
  "shared-key" = {
    description   = "Service-to-service shared key"
    length        = 64
    tags          = {}
    value_version = lookup(var.value_versions, "shared-key", 1)
  }
}
```

The dev root only invokes the complete application module:

```hcl
module "application_secrets" {
  source = "../../modules/application-secrets"

  application_name = var.application_name
  environment      = var.environment
  tags             = local.effective_tags
  value_versions   = var.value_versions
}
```

## Rotation

Every secret starts with `value_version = 1`. Repeated applies and metadata-only
changes do not write a new value. To rotate one secret, increase its counter:

```hcl
value_versions = {
  "service-password" = 2
}
```

Terraform then generates and writes one new Secrets Manager version without
replacing the AWS secret itself. Counters must not be decreased or reused.

## GitHub configuration

Configure these Actions secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`

Configure these repository variables:

- `AWS_REGION`, for example `eu-central-1`;
- `TF_STATE_BUCKET`, a globally unique bucket name;
- `TF_STATE_KEY`, for example `orders-api/dev/terraform.tfstate`;
- `APPLICATION_NAME`, for example `orders-api`.

Use credentials with access to the state bucket and the application Secrets
Manager path. For a real environment, prefer GitHub OIDC and a dedicated IAM
role over long-lived access keys.

## Bootstrap and deployment

1. Run **Actions → Bootstrap Terraform backend** once. It creates the encrypted,
   versioned, private S3 bucket and enables native S3 state locking.
2. Open a pull request. `pull-request.yml` checks formatting and validation,
   runs the static security check, and plans against the remote state.
3. Merge to `main`. `deploy.yml` creates and applies a fresh Terraform plan.

`Terraform infrastructure` can also be started manually with `apply` or
`destroy`. Destroy removes the application secrets but keeps the backend and
state bucket. Secrets use a seven-day AWS recovery window, so their names cannot
be recreated immediately while deletion is pending.

## Checks

Run the normal repository checks with:

```bash
make check
```

The scripts have separate responsibilities:

- `check-no-persistent-secrets.sh` rejects managed secret generators and
  non-write-only Secrets Manager value arguments;
- `verify-lifecycle.sh` runs the end-to-end apply, no-op, tag-only, rotation,
  and cleanup sequence in an isolated Terraform workspace;
- `verify.py` checks AWS version IDs and scans state and plan artifacts without
  printing live secret values.

After initializing `environments/dev` against its backend, run the full AWS
lifecycle verification with:

```bash
./scripts/verify-lifecycle.sh
```

The test proves that values are non-empty, absent from state and saved plans,
stable across repeated and tag-only applies, rotated only by `value_version`,
and rotated without replacing the Secrets Manager secret.
