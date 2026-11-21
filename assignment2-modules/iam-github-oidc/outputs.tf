output "plan_role_arn" {
  description = "Repository variable TF_PLAN_ROLE_ARN in GitHub"
  value       = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  description = "Environment variable TF_APPLY_ROLE_ARN: use the dev ARN in the dev environment and the prod ARN in the prod environment"
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}
