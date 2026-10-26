output "kms_key_arn" {
  value = aws_kms_key.terraform_state.arn
}

output "kms_key_alias" {
  value = aws_kms_alias.terraform_state.name
}

output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "state_admin_role_arn" {
  value = aws_iam_role.terraform_state_admin.arn
}