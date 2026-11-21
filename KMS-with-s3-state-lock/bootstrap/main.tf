terraform {
  required_version = ">= 1.5.0"

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

# ---------------------------------------------------------------
# CONCEPT: bootstrap (the chicken-and-egg problem)
# The main project stores its state in an S3 bucket, so that bucket
# must exist BEFORE the main project can run. This folder creates it.
# Its own state stays LOCAL (bootstrap/terraform.tfstate) - keep it.
# ---------------------------------------------------------------

resource "random_pet" "suffix" {
  length = 2
}

# CONCEPT: count as an on/off switch
# count = 1 creates the resource, count = 0 skips it. Resources made
# with count are lists, so we refer to them as aws_kms_key.state[0].
resource "aws_kms_key" "state" {
  count = var.production_grade ? 1 : 0

  description             = "Encrypts Terraform state files"
  enable_key_rotation     = true # AWS rotates the key material yearly
  deletion_window_in_days = 7    # minimum wait before a deleted key is gone (billed until then)
}

resource "aws_kms_alias" "state" {
  count = var.production_grade ? 1 : 0

  name          = "alias/tfstate-${random_pet.suffix.id}"
  target_key_id = aws_kms_key.state[0].key_id
}

resource "aws_s3_bucket" "state" {
  bucket = "tfstate-${random_pet.suffix.id}"

  # Learning: true so 'terraform destroy' can clean up everything.
  # Production: false so nobody can wipe the history of your infrastructure.
  force_destroy = !var.production_grade

  # CONCEPT: lifecycle meta-argument
  # In real production, uncomment this. Terraform will then REFUSE any plan
  # that would delete this bucket. (It cannot be driven by a variable.)
  # lifecycle {
  #   prevent_destroy = false
  # }

  tags = {
    Purpose   = "terraform-state"
    ManagedBy = "terraform"
  }
}

# 1) Nothing in this bucket may ever be public.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2) Turn off legacy ACLs; only bucket policies and IAM control access.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# 3) Versioning: every write keeps the previous copy, so a corrupted or
#    deleted state file can be restored. This is the most important
#    setting on a state bucket.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 4) Encryption at rest. State can contain secrets (passwords, keys).
#    AES256 = SSE-S3 (free). aws:kms = your own key: you control who can
#    decrypt, and every use is logged in CloudTrail.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.production_grade ? "aws:kms" : "AES256"
      # one() turns a 0-or-1 item list into a value or null
      kms_master_key_id = one(aws_kms_key.state[*].arn)
    }
    # Bucket keys cut KMS request costs (only meaningful with KMS)
    bucket_key_enabled = var.production_grade
  }
}

# 5) Versioning keeps growing; expire old versions after N days.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {} # empty filter = applies to the whole bucket

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # CONCEPT: depends_on
  # Terraform normally works out ordering from references. Here there is
  # no reference, but S3 requires versioning first, so we say it explicitly.
  depends_on = [aws_s3_bucket_versioning.state]
}

# 6) Refuse any request that is not HTTPS.
resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.state.arn,
        "${aws_s3_bucket.state.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}
