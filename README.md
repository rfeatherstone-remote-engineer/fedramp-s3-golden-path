# fedramp-s3-golden-path

[![FedRAMP High Terraform Guardrails CI](https://github.com/rfeatherstone-remote-engineer/fedramp-s3-golden-path/actions/workflows/ci.yml/badge.svg)](https://github.com/rfeatherstone-remote-engineer/fedramp-s3-golden-path/actions/workflows/ci.yml)

Preventive Infrastructure-as-Code (Terraform) guardrails for **GovTech & Defense** workloads aligned to **FedRAMP High**, **NIST SP 800-53 Rev. 5**, **FIPS 140-3**, and **DoD Cloud Computing SRG (IL4/IL5)**.

> **Companion Repository:** Pairs with [`govtech-s3-telemetry-lab`](https://github.com/rfeatherstone-remote-engineer/govtech-s3-telemetry-lab) for detective CUI/EDIPI telemetry sanitization, SLO burn-rate alerting, and circuit-breaker self-healing.

## Architecture Diagram

```text
  [ Terraform CI / Authorized IaC Role ]
                    │  (AC-6 Anti-ClickOps Bucket Policy)
                    ▼
  ┌───────────────────────────────────────────────────────────┐
  │  Primary CUI Vault (S3 + Object Lock COMPLIANCE >= 2190d) │
  │  • SSE-KMS FIPS 140-3 CMK + Auto Rotation (SC-28)         │
  │  • TLS-Only SecureTransport Enforcement (SC-8)            │
  │  • Versioning + Glacier Lifecycle Archival (CP-9)         │
  └─────────────────────────────┬─────────────────────────────┘
                                │ Server Access Logs (AU-9)
                                ▼
  ┌───────────────────────────────────────────────────────────┐
  │  Immutable Audit Logs Bucket (Object Lock >= 2190d)       │
  │  • Dedicated KMS CMK + Block Public Access + TLS-Only     │
  └───────────────────────────────────────────────────────────┘
```

## Compliance Control Matrix

| Control Family | Requirement | Preventive Guardrail Enforced |
| :--- | :--- | :--- |
| **SC-28 / FIPS 140-3** | Protection at Rest | Dedicated KMS CMK (`enable_key_rotation = true`) + bucket policy denying `s3:PutObject` without `aws:kms`. |
| **SC-8** | Transmission Security | Explicit `aws:SecureTransport = false` deny policies on both CUI and audit-log buckets. |
| **AU-9** | Audit Protection | S3 Object Lock in `COMPLIANCE` mode (`retention_days >= 2190` / 6 years) + isolated server access logging. |
| **AC-6** | Anti-ClickOps | Bucket policy denying manual policy, encryption, versioning, Object Lock, or deletion outside `authorized_iac_role_arns`. |
| **CP-9** | Backup & Lifecycle | Mandatory versioning + Glacier archival rules for noncurrent CUI versions and audit logs. |

## Usage

```hcl
module "fedramp_cui_vault" {
  source                   = "github.com/rfeatherstone-remote-engineer/fedramp-s3-golden-path"
  bucket_name              = "dod-agency-cui-telemetry-vault-001"
  aws_account_id           = "123456789012"
  aws_partition            = "aws-us-gov"
  retention_days           = 2190
  authorized_iac_role_arns = ["arn:aws-us-gov:iam::123456789012:role/GitHubActionsTerraformDeployRole"]
}
```
