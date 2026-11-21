terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "tfstate-capable-leopard"
    key          = "assignment2/prod/terraform.tfstate" # different file from dev
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
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
  force_destroy     = true
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
