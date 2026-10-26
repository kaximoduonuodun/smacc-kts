# bootstrap/terraform.tfvars
# 改这三行：
# 1. aws_profile：你本地 ~/.aws/config 里的 profile 名
# 2. state_bucket_name：改成你自己的，必须全球唯一（别人用过就不行）
# 3. terraform_user_arn：本地 IAM 用户的 ARN

aws_region         = "ap-southeast-1"
aws_profile        = "default"
project_name       = "smacc-kts"
state_bucket_name  = "smacc-kts-terraform-state"
terraform_user_arn = "arn:aws:iam::867660044892:user/terraform-user"
