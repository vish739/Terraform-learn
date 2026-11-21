variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Environment name (dev, test or prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete the bucket even if it has files"
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "Keep old versions of files in the bucket"
  type        = bool
  default     = false
}
