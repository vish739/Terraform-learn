# ------------------------------------------------------------------
# GitHub Actions -> AWS without access keys (OIDC)
#
# How it works:
#   1. GitHub gives each workflow job a short-lived signed token (JWT).
#   2. The token says WHO is asking in its "sub" claim, e.g.
#        repo:owner/name:pull_request
#        repo:owner/name:ref:refs/heads/main
#        repo:owner/name:environment:prod
#   3. AWS checks the token against the OIDC provider, then against the
#      role's TRUST POLICY. Only matching "sub" values may assume the role.
#   4. AWS returns temporary credentials (1 hour).
#
# Three roles, least privilege:
#   github-tf-plan        read-only, used for PR plans and the prod plan
#   github-tf-apply-dev   can change only dev, only from the 'dev' environment
#   github-tf-apply-prod  can change only prod, only from the 'prod' environment
#                         (which is the one that needs human approval)
# ------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  oidc_host        = "token.actions.githubusercontent.com"
  repo             = var.github_repository
  state_bucket_arn = "arn:aws:s3:::${var.state_bucket_name}"
  state_prefix     = "assignment2" # first part of the 'key' in each backend block
  environments     = toset(["dev", "prod"])
}

# --- The OIDC provider: tells AWS to trust tokens issued by GitHub ---
# AWS no longer checks the thumbprint for GitHub, but older provider
# versions still require the argument, so it is set.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://${local.oidc_host}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://${local.oidc_host}"
}

locals {
  # one() turns a 0-or-1 item list into a value; coalesce picks the first non-null
  oidc_provider_arn = coalesce(
    one(aws_iam_openid_connect_provider.github[*].arn),
    one(data.aws_iam_openid_connect_provider.existing[*].arn),
  )
}

# ==================================================================
# PLAN role: read-only. Allowed from pull requests and from main.
# ==================================================================
data "aws_iam_policy_document" "plan_trust" {
  statement {
    sid     = "GitHubOidcPlan"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # StringEquals (no wildcards): only these exact callers
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values = [
        "repo:${local.repo}:pull_request",
        "repo:${local.repo}:ref:refs/heads/main",
      ]
    }
  } 
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket_arn}/${local.state_prefix}/*"]
  }

  # 'terraform plan' still takes the state lock (a small .tflock object)
  statement {
    sid       = "StateLockFiles"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/${local.state_prefix}/*/terraform.tfstate.tflock"]
  }

  statement {
    sid       = "ReadManagedBuckets"
    actions   = ["s3:Get*", "s3:List*"]
    resources = ["arn:aws:s3:::tf-mod-*", "arn:aws:s3:::tf-mod-*/*"]
  }

  statement {
    sid       = "ListAllBuckets"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  # Only added when the state is encrypted with your own KMS key
  dynamic "statement" {
    for_each = var.state_kms_key_arn == "" ? [] : [1]
    content {
      sid       = "StateKms"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      resources = [var.state_kms_key_arn]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "github-tf-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "plan" {
  name   = "tf-plan"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

# ==================================================================
# APPLY roles: one per environment. Only a job that runs inside the
# matching GitHub *environment* can assume it. For prod that job only
# starts after the required reviewer approves.
# ==================================================================
data "aws_iam_policy_document" "apply_trust" {
  for_each = local.environments

  statement {
    sid     = "GitHubOidcApply${title(each.key)}"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${local.repo}:environment:${each.key}"]
    }
  }
}

data "aws_iam_policy_document" "apply" {
  for_each = local.environments

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  # Only THIS environment's state file and lock file
  statement {
    sid       = "StateForThisEnvironment"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/${local.state_prefix}/${each.key}/*"]
  }

  # Only buckets whose names start with tf-mod-<env>-
  statement {
    sid     = "ManageBucketsForThisEnvironment"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::tf-mod-${each.key}-*",
      "arn:aws:s3:::tf-mod-${each.key}-*/*",
    ]
  }

  statement {
    sid       = "ListAllBuckets"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.state_kms_key_arn == "" ? [] : [1]
    content {
      sid       = "StateKms"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      resources = [var.state_kms_key_arn]
    }
  }
}

resource "aws_iam_role" "apply" {
  for_each = local.environments

  name                 = "github-tf-apply-${each.key}"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust[each.key].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "apply" {
  for_each = local.environments

  name   = "tf-apply-${each.key}"
  role   = aws_iam_role.apply[each.key].id
  policy = data.aws_iam_policy_document.apply[each.key].json
}
