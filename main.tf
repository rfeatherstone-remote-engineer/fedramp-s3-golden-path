data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_kms_key" "fedramp_s3" {
  description             = "FedRAMP High CMK for ${var.bucket_name} (SC-28 / FIPS 140-3)"
  deletion_window_in_days = var.kms_key_deletion_window_days
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowS3ServiceUseOfKey"
        Effect    = "Allow"
        Principal = { Service = "://amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
      }
    ]
  })
  tags = var.tags
}

resource "aws_kms_alias" "fedramp_s3" {
  name          = "alias/${var.bucket_name}-cmk"
  target_key_id = aws_kms_key.fedramp_s3.key_id
}

resource "aws_s3_bucket" "access_logs" {
  bucket              = "${var.bucket_name}-audit-logs"
  object_lock_enabled = true
  tags                = var.tags
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.fedramp_s3.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "access_logs" {
  bucket     = aws_s3_bucket.access_logs.id
  depends_on = [aws_s3_bucket_versioning.access_logs]
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.retention_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket     = aws_s3_bucket.access_logs.id
  depends_on = [aws_s3_bucket_versioning.access_logs]
  rule {
    id     = "fedramp-au9-audit-log-retention"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration { days = var.retention_days + 30 }
  }
}

resource "aws_s3_bucket_policy" "access_logs_tls" {
  bucket     = aws_s3_bucket.access_logs.id
  depends_on = [aws_s3_bucket_public_access_block.access_logs]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnforceTLSOnlyOnAuditLogs"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.access_logs.arn, "${aws_s3_bucket.access_logs.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_s3_bucket" "cui_vault" {
  bucket              = var.bucket_name
  object_lock_enabled = true
  tags                = var.tags
}

resource "aws_s3_bucket_versioning" "cui_vault" {
  bucket = aws_s3_bucket.cui_vault.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_object_lock_configuration" "cui_vault" {
  bucket     = aws_s3_bucket.cui_vault.id
  depends_on = [aws_s3_bucket_versioning.cui_vault]
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.retention_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cui_vault" {
  bucket     = aws_s3_bucket.cui_vault.id
  depends_on = [aws_s3_bucket_versioning.cui_vault]
  rule {
    id     = "fedramp-cp9-cui-lifecycle"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cui_vault" {
  bucket = aws_s3_bucket.cui_vault.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.fedramp_s3.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cui_vault" {
  bucket                  = aws_s3_bucket.cui_vault.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "cui_vault" {
  bucket        = aws_s3_bucket.cui_vault.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "s3-access-logs/${var.bucket_name}/"
  depends_on    = [aws_s3_bucket_policy.access_logs_tls]
}

resource "aws_s3_bucket_policy" "cui_vault_guardrails" {
  bucket     = aws_s3_bucket.cui_vault.id
  depends_on = [aws_s3_bucket_public_access_block.cui_vault]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.cui_vault.arn, "${aws_s3_bucket.cui_vault.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "DenyUnencryptedUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cui_vault.arn}/*"
        Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" } }
      },
      {
        Sid       = "ForbidManualStateMutation"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:PutBucketPublicAccessBlock", "s3:PutEncryptionConfiguration", "s3:PutBucketVersioning", "s3:PutObjectLockConfiguration", "s3:PutBucketLogging", "s3:DeleteBucket"]
        Resource  = aws_s3_bucket.cui_vault.arn
        Condition = { ArnNotEquals = { "aws:PrincipalArn" = var.authorized_iac_role_arns } }
      }
    ]
  })
}
