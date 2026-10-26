variable "project_name" {
  type    = string
  default = "smacc-kts"
}

variable "environment" {
  type    = string
  default = "e2e"
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "key_name" {
  type    = string
  default = "nuodun"
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