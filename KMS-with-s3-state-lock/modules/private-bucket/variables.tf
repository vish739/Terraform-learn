variable "name_prefix" {
  description = "Start of the bucket name, e.g. tf-mod"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test or prod)"
  type        = string

  # CONCEPT: validation - fail early with a clear message
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "force_destroy" {
  description = "Allow destroy to delete the bucket even if it contains files. Keep false in prod."
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Keep old versions of files. Recommended in prod."
  type        = bool
  default     = false
}

# CONCEPT: complex types - a map whose values are objects
variable "files" {
  description = "Files to upload: map of object key => content and content type"
  type = map(object({
    content      = string
    content_type = string
  }))
  default = {}
}
