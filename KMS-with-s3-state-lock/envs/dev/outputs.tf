# Module outputs are read as module.<name>.<output>
output "bucket_name" {
  value = module.site_bucket.bucket_name
}

output "object_keys" {
  value = module.site_bucket.object_keys
}
