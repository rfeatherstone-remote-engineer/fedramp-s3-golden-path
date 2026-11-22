variable "bucket_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 lowercase alphanumeric chars, dots, or hyphens."
  }
}

variable "aws_account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_partition" {
  type    = string
  default = "aws-us-gov"
  validation {
    condition     = contains(["aws", "aws-us-gov"], var.aws_partition)
    error_message = "aws_partition must be aws or aws-us-gov."
  }
}

variable "retention_days" {
  type    = number
  default = 2190
  validation {
    condition     = var.retention_days >= 2190
    error_message = "FedRAMP High requires retention_days >= 2190 (6 years)."
  }
}

variable "authorized_iac_role_arns" {
  type = list(string)
}

variable "kms_key_deletion_window_days" {
  type    = number
  default = 30
  validation {
    condition     = var.kms_key_deletion_window_days >= 7 && var.kms_key_deletion_window_days <= 30
    error_message = "KMS key deletion window must be 7-30 days."
  }
}

variable "tags" {
  type = map(string)
  default = {
    ComplianceFramework = "FedRAMP-High-NIST-800-53-Rev5"
    ImpactLevel         = "DoD-SRG-IL4-IL5"
    DataClassification  = "CUI"
    ManagedBy           = "Terraform"
  }
}
