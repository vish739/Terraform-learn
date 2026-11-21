# Assignment 2: modules, folder per environment, hardened buckets

## Layout

```
bootstrap/            creates the STATE bucket (run once, state stays local)
modules/private-bucket/   reusable hardened bucket (inputs, resources, outputs)
envs/dev/             thin folder: backend + module call with dev values
envs/prod/            same module, prod values, separate state file
```

## Order of work

1. `cd bootstrap` -> `terraform init` -> `terraform apply` (learning mode)
   or `terraform apply -var="production_grade=true"` (see warning below)
2. Copy `state_bucket_name` into `envs/dev/main.tf` and `envs/prod/main.tf`
3. `cd envs/dev` -> `terraform init` -> `terraform plan` -> `terraform apply`
4. `cd envs/prod` -> same
5. Destroy in reverse: dev, prod (set force_destroy = true and apply first), then bootstrap

## State bucket vs other buckets: recommended settings

| Setting | State bucket (learning) | State bucket (production) | Regular private data bucket (prod) |
|---|---|---|---|
| Block all public access | On | On | On |
| Versioning | On | On (essential: undo bad or lost state) | On for important data |
| Encryption | SSE-S3 (AES256) | SSE-KMS with own key, rotation on | SSE-S3 or SSE-KMS by data sensitivity |
| HTTPS-only policy | Yes | Yes | Yes |
| ACLs disabled (BucketOwnerEnforced) | Yes | Yes | Yes |
| force_destroy | true (easy cleanup) | false | false |
| prevent_destroy lifecycle | No | Yes | Yes |
| Old-version expiry | 90 days | 90+ days (match your recovery needs) | Per data policy (tiering, expiry) |
| Who can access | Your IAM user | Only the CI/CD role and a few admins | Application roles, least privilege |
| Access logging / CloudTrail data events | No | Yes (audit who read or changed state) | Yes for sensitive data |
| Cross-region replication | No | Optional, for disaster recovery | Depends on RPO |
| Separate AWS account | No | Yes (dedicated account or per environment) | Usually the application's account |
| Locking | use_lockfile | use_lockfile | Not applicable |

Why state is special: it lists every resource and can contain secrets in
plain text, and losing it means Terraform no longer knows what it manages.

Implemented in `bootstrap/`: public access block, ownership controls,
versioning, encryption (SSE-S3 or KMS), lifecycle expiry, HTTPS-only,
force_destroy toggle, commented prevent_destroy.
Described but NOT implemented here: access logging, CloudTrail data events,
replication, dedicated account, tight bucket policy for specific roles.

## Concepts used and where

| Concept | File |
|---|---|
| Bootstrap / backend / state key | `bootstrap/main.tf`, `envs/*/main.tf` |
| Variables, validation, complex types | `modules/private-bucket/variables.tf` |
| Locals | `modules/private-bucket/main.tf` |
| count as on/off switch, one() | `bootstrap/main.tf` (KMS) |
| for_each | `modules/private-bucket/main.tf` (files) |
| Conditional expression | `modules/private-bucket/main.tf` (versioning) |
| depends_on | `bootstrap/main.tf`, module bucket policy |
| lifecycle (prevent_destroy) | `bootstrap/main.tf` (commented) |
| Module call and outputs | `envs/*/main.tf`, `envs/*/outputs.tf` |

## Warning for production_grade = true

* Your IAM user needs KMS permissions or apply fails with AccessDenied.
  The AWS managed policy AWSKeyManagementServicePowerUser may not cover every
  action Terraform needs (enabling rotation, scheduling deletion, encrypting
  and decrypting state). For practice, add an inline policy allowing
  kms:* on * to the user. In real projects, scope it to the key's ARN.
* A KMS key costs about $1/month plus requests, until fully deleted
  (7-day wait after destroy).
* Environments that use this bucket also need permission to use the key,
  or `terraform init` and `apply` fail when reading or writing state.

## CI/CD with GitHub Actions (Phases 2 and 5)

Extra folders: `iam-github-oidc/` (run once by an admin) and `.github/workflows/terraform.yml`.
Flow: PR -> plan comments for dev and prod; merge -> dev applies; prod plan is
posted, a reviewer approves the `prod` environment, then the SAME plan is applied.
Required reviewers on environments need a PUBLIC repository on GitHub Free,
or GitHub Pro/Team for private repositories.
