terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_pet" "name" {
  length    = 2
  separator = "_"
  prefix    = "demo"
}

resource "local_file" "hello" {
  filename = "${path.module}/hello-${random_pet.name.id}.txt"
  content  = "Hello from Terraform, ${random_pet.name.id}!"
}

output "file_name" {
  value = local_file.hello.filename
}