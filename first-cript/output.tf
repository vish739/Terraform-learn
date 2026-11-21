output "environment" {
  value = var.environment
}

output "bucket_name" {
  description = "Name of the private S3 bucket"
  value       = aws_s3_bucket.practice.id
}

output "object_keys" {
  description = "Files stored in the bucket"
  value = [
    aws_s3_object.hello.key,
    aws_s3_object.index.key,
    aws_s3_object.error.key,
  ]
}

output "presign_command" {
  description = "Run this to get a temporary link to index.html (valid 1 hour)"
  value       = "aws s3 presign s3://${aws_s3_bucket.practice.id}/${aws_s3_object.index.key} --expires-in 3600"
}
