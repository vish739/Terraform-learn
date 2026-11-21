variable "aws_region" {
  description = "Region for the AWS provider (IAM itself is global)"
  type        = string
  default     = "ap-southeast-2"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the roles, as owner/name (case matters)"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use the form owner/repository, for example vishalrane/terraform-assignment."
  }
}

variable "state_bucket_name" {
  description = "Name of the Terraform state bucket created by bootstrap"
  type        = string
}

variable "state_kms_key_arn" {
  description = "Optional: KMS key ARN if the state is encrypted with your own key"
  type        = string
  default     = ""
}

variable "create_oidc_provider" {
  description = "Set false if this account already has the GitHub OIDC provider (only one is allowed per account)"
  type        = bool
  default     = true
}
