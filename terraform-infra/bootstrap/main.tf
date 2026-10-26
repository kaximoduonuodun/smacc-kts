############################################
# bootstrap/main.tf
# create S3 state bicket + KMS + DynamoDB lock table + IAM role, manage all resource with S3 bucket
############################################

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.90"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  backend "s3" {
    bucket         = "smacc-kts-terraform-state"
    key            = "bootstrap/terraform.tfstate"
    region         = "ap-southeast-1"
    #dynamodb_table = "smacc-kts-terraform-locks"
    use_lockfile   = true
    encrypt        = true
    kms_key_id     = "alias/smacc-kts-terraform-state"
    profile        = "default"
  }


}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_caller_identity" "current" {}


# KMS encrypt state

resource "aws_kms_key" "terraform_state" {
  description             = "Terraform state bucket encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow root account full access"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow StateAdmin role to use key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.terraform_state_admin.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = { managed_by = "terraform" }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${var.project_name}-terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}


# S3 bucket for tf.state
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = { managed_by = "terraform" }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# bucket policy,forced KMS encrypt ,just allow  StateAdmin role
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.terraform_state.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "DenyIncorrectEncryptionKey"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.terraform_state.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.terraform_state.arn
          }
        }
      },
      {
        Sid       = "DenyNonStateAdminAccess"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          StringNotLike = {
            "aws:PrincipalArn" = [
              aws_iam_role.terraform_state_admin.arn,
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/nuodun",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {
      prefix = ""
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# IAM role for apply
resource "aws_iam_role" "terraform_admin" {
  name = "${var.project_name}-terraform-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/nuodun",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
          var.terraform_user_arn
        ]
      }
      Condition = {
        Bool = { "aws:MultiFactorAuthPresent" = "true" }
      }
    }]
  })

  tags = { managed_by = "terraform" }
}

# 个人项目直接给管理员权限，团队场景应换成具体权限
resource "aws_iam_role_policy_attachment" "terraform_admin_full" {
  role       = aws_iam_role.terraform_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ============================================================
# IAM 角色：只管 state 桶（职责分离）
# ============================================================
resource "aws_iam_role" "terraform_state_admin" {
  name = "${var.project_name}-terraform-state-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/nuodun",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
          var.terraform_user_arn
        ]
      }
      Condition = {
        Bool = { "aws:MultiFactorAuthPresent" = "true" }
      }
    }]
  })

  tags = { managed_by = "terraform" }
}

resource "aws_iam_role_policy" "terraform_state_admin_policy" {
  name = "${var.project_name}-state-bucket-access"
  role = aws_iam_role.terraform_state_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:GetObjectVersion", "s3:ListBucket",
          "s3:GetBucketVersioning", "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"
        ]
        Resource = aws_kms_key.terraform_state.arn
      }
    ]
  })

}
