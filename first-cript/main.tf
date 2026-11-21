terraform {
  # use_lockfile (S3 state locking) needs Terraform 1.10 or newer
  required_version = ">= 1.10.0"

  # Details (bucket, key, region) come from backend-<env>.hcl at init time
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "random_pet" "name" {
  length = 2
}

# Private bucket, name includes the environment
resource "aws_s3_bucket" "practice" {
  bucket        = "tf-practice-${var.environment}-${random_pet.name.id}"
  force_destroy = var.force_destroy

  tags = {
    Project     = "terraform-practice"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "practice" {
  bucket                  = aws_s3_bucket.practice.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "practice" {
  bucket = aws_s3_bucket.practice.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "practice" {
  bucket = aws_s3_bucket.practice.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# ---- Files stored in the private bucket ----

resource "aws_s3_object" "hello" {
  bucket       = aws_s3_bucket.practice.id
  key          = "hello-${var.environment}-${random_pet.name.id}.txt"
  content      = "Hello from Terraform (${var.environment}), ${random_pet.name.id}!"
  content_type = "text/plain"
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.practice.id
  key          = "index.html"
  content_type = "text/html"
  content      = <<-HTML
    <!DOCTYPE html>
    <html>
      <head><title>My Terraform Page (${var.environment})</title></head>
      <body>
        <h1>Hello from Terraform - ${upper(var.environment)}</h1>
        <p>Stored in the private S3 bucket: ${aws_s3_bucket.practice.id}</p>
      </body>
    </html>
  HTML
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.practice.id
  key          = "error.html"
  content_type = "text/html"
  content      = "<html><body><h1>404 - Page not found (${var.environment})</h1></body></html>"
}
