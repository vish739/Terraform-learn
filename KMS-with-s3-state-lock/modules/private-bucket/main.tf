# ---------------------------------------------------------------
# CONCEPT: module
# A module is a folder of Terraform code with inputs (variables.tf)
# and outputs (outputs.tf). Callers pass inputs and read outputs, so
# the same hardened bucket can be created many times without copy-paste.
# A module declares which providers it needs but does NOT configure
# them - the calling environment does that.
# ---------------------------------------------------------------
terraform {
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

resource "random_pet" "suffix" {
  length = 2
}

# CONCEPT: locals
# Named values computed once and reused (like a variable you cannot
# set from outside).
locals {
  bucket_name = "${var.name_prefix}-${var.environment}-${random_pet.suffix.id}"
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Security baseline (same ideas as the state bucket):
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CONCEPT: conditional expression  condition ? value_if_true : value_if_false
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.this.arn,
        "${aws_s3_bucket.this.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# CONCEPT: for_each
# Creates one resource per item in a map. each.key / each.value are the
# current item. Adding or removing a map entry adds or removes only that
# object, which is why for_each is preferred over count for named things.
resource "aws_s3_object" "files" {
  for_each = var.files

  bucket       = aws_s3_bucket.this.id
  key          = each.key
  content      = each.value.content
  content_type = each.value.content_type
}
