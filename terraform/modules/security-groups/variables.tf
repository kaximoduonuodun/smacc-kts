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

variable "vpc_id" {
  type = string
}