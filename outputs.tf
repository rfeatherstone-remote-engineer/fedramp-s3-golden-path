output "cui_bucket_id" { value = aws_s3_bucket.cui_vault.id }
output "cui_bucket_arn" { value = aws_s3_bucket.cui_vault.arn }
output "audit_logs_bucket_id" { value = aws_s3_bucket.access_logs.id }
output "kms_key_arn" { value = aws_kms_key.fedramp_s3.arn }
output "retention_days_enforced" { value = var.retention_days }
