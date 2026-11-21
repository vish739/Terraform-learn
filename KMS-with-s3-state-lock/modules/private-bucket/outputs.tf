output "bucket_name" {
  description = "Name of the bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the bucket (used in IAM policies)"
  value       = aws_s3_bucket.this.arn
}

output "object_keys" {
  description = "Keys of the uploaded files"
  value       = keys(aws_s3_object.files)
}
