variable "project_name" {
  type = string
}

variable "environment" {
  type = string
  description = "env name, such as e2e/prod"

  validation {
    condition     = contains(["dev","test","e2e", "prod"], var.environment)
    error_message = "environment must be dev/e2e/prod"
  }
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
  description = "available zones list"
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "public_subnet_cidrs" {
  type = list(string)
}