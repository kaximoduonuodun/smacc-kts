############################################
# bootstrap/variables.tf
############################################

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "aws_profile" {
  type        = string
  description = "本地 AWS profile 名，对应 ~/.aws/config 里的 profile"
}

variable "project_name" {
  type    = string
  default = "smacc-kts"
}

variable "state_bucket_name" {
  type        = string
  description = "S3 桶名，必须全局唯一，自己改一个"
}

variable "lock_table_name" {
  type    = string
  default = "smacc-kts-terraform-locks"
}

variable "terraform_user_arn" {
  type        = string
  description = "你本地 IAM 用户的 ARN，用来做 AssumeRole 信任"
}
