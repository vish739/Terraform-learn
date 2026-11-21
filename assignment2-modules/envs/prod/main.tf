terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "tfstate-funky-meerkat"
    key          = "assignment2/prod/terraform.tfstate" # different file from dev
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

# PROD choices: protected from accidental deletion and keeps history.
module "site_bucket" {
  source = "../../modules/private-bucket"

  name_prefix       = "tf-mod"
  environment       = "prod"
  force_destroy     = false # to tear down prod: set true, apply, then destroy
  enable_versioning = true

  files = {
    "index.html" = {
      content      = "<html><body><h1>Hello from PROD</h1></body></html>"
      content_type = "text/html"
    }
    "notes.txt" = {
      content      = "prod notes"
      content_type = "text/plain"
    }
  }
}
