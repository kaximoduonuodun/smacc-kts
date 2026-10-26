variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

variable "key_name" {
  type = string
}

variable "kms_key_arn" {
  type        = string
  description = "CMK ARN for encrypting EC2 root volumes"
  sensitive   = true   #tags for sensitive, will show ** in plan list
}

variable "server_instance_type" {
  type    = string
  default = "t3.small"
}

variable "agent_instance_type" {
  type    = string
  default = "t3.small"
}

variable "agent_count" {
  type    = number
  default = 2
}