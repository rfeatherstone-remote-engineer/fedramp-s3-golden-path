# fedramp-s3-golden-path

[![FedRAMP High Terraform Guardrails CI](httpsgithub.com/rfeatherstone-remote-engineer/fedramp-s3-golden-path"fedramp_cui_vault" {
  source                   = "github.com/rfeatherstone-remote-engineer/fedramp-s3-golden-path"
  bucket_name              = "dod-agency-cui-telemetry-vault-001"
  aws_account_id           = "123456789012"
  aws_partition            = "aws-us-gov"
  retention_days           = 2190
  authorized_iac_role_arns = ["arn:aws-us-gov:iam::123456789012:role/GitHubActionsTerraformDeployRole"]
}
```
