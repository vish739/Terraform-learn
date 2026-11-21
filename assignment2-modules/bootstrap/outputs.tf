# CONCEPT: outputs
# Outputs print values after apply and let other code read them.

output "state_bucket_name" {
  description = "Paste this into the backend block of each environment"
  value       = aws_s3_bucket.state.id
}

output "kms_key_arn" {
  description = "KMS key used for encryption (null in learning mode)"
  value       = one(aws_kms_key.state[*].arn)
}

output "backend_snippet" {
  description = "Ready-made backend block for envs/<env>/main.tf"
  value       = <<-EOT
    backend "s3" {
      bucket       = "${aws_s3_bucket.state.id}"
      key          = "assignment2/<env>/terraform.tfstate"
      region       = "${var.aws_region}"
      encrypt      = true
      use_lockfile = true
    }
  EOT
}
