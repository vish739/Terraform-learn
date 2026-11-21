# ---------------------------------------------------------------
# CONCEPT: input variables
# Variables make one piece of code behave differently without
# editing it. You set them with -var, a .tfvars file, or defaults.
# ---------------------------------------------------------------

variable "aws_region" {
  description = "Region where the state bucket is created"
  type        = string
  default     = "ap-southeast-2"
}

variable "production_grade" {
  description = <<-EOT
    false = learning setup: SSE-S3 encryption, easy to destroy.
    true  = production-style setup: KMS key with rotation, and the bucket
            is NOT force-destroyable.
    NOTE: true needs KMS permissions on your IAM user (the
    AmazonS3FullAccess policy alone is not enough) and the KMS key
    costs about $1/month until it is deleted.
  EOT
  type        = bool
  default     = false
}

variable "noncurrent_version_days" {
  description = "Days to keep OLD versions of state files before S3 deletes them"
  type        = number
  default     = 90
}
