provider "aws" {
  region                      = "us-gov-west-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

module "fedramp_cui_vault" {
  source                   = "../../"
  bucket_name              = "dod-agency-cui-telemetry-vault-001"
  aws_account_id           = "123456789012"
  aws_partition            = "aws-us-gov"
  retention_days           = 2190
  authorized_iac_role_arns = ["arn:aws-us-gov:iam::123456789012:role/GitHubActionsTerraformDeployRole"]
}
