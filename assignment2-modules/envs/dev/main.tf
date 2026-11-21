terraform {
  required_version = ">= 1.10.0" # use_lockfile needs 1.10+

  # ---------------------------------------------------------------
  # CONCEPT: backend
  # Tells Terraform where to keep the state file. 'key' is the path of
  # the file inside the bucket, so each environment gets its own file.
  # use_lockfile stops two runs changing the same state at once.
  # Backend blocks cannot use variables, so values are written out.
  # ---------------------------------------------------------------
  backend "s3" {
    bucket       = "tfstate-funky-meerkat"
    key          = "assignment2/dev/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
    kms_key_id   =  "arn:aws:kms:ap-southeast-2:306077570508:key/31c05716-f80d-4238-af3d-d713e178fde4"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# ---------------------------------------------------------------
# CONCEPT: calling a module
# source = path to the module folder. Everything below is an input.
# DEV choices: easy to throw away (force_destroy = true), no versioning.
# ---------------------------------------------------------------
module "site_bucket" {
  source = "../../modules/private-bucket"

  name_prefix       = "tf-mod"
  environment       = "dev"
  force_destroy     = true
  enable_versioning = false

  files = {
    "index.html" = {
      content      = "<html><body><h1>Hello from DEV</h1></body></html>"
      content_type = "text/html"
    }
    "notes.txt" = {
      content      = "dev notes"
      content_type = "text/plain"
    }
  }
}
