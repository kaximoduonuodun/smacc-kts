variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}


variable "aws_region" {
  type    = string
  default = "ap-southeast-1"   # ← 加默认值
}