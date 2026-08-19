# Mentor Infra

Terraform for AWS resources (API hosting, Postgres/RDS, SQS, EventBridge, auth). Populated once Phase 1 infra needs are defined; see [../docs/technical_spec.md](../docs/technical_spec.md).

## Remote state

`bootstrap/` is a one-time, self-contained Terraform config (local state — it creates the very backend everything else uses, so it can't depend on it). It has already been applied and created:

- S3 bucket: `mentor-tfstate-384668480848` (versioned, encrypted, public access blocked) — region `ca-central-1`
- DynamoDB table: `mentor-tfstate-lock` — used for state locking

Every other Terraform config in this repo (once created) should point at this backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "mentor-tfstate-384668480848"
    key            = "<component-name>/terraform.tfstate"  # e.g. "api/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "mentor-tfstate-lock"
    encrypt        = true
  }
}
```

Don't re-run `bootstrap/` unless the state bucket/lock table need to be recreated from scratch.
