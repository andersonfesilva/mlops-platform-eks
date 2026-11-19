terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}

locals {
  # "arn:aws:iam::123456789012:oidc-provider/oidc.eks.<region>.amazonaws.com/id/XXXX" -> issuer host/path
  oidc_issuer = element(split("oidc-provider/", var.oidc_provider_arn), 1)
}

# Trust policy pinned to ONE service account in ONE namespace (sub) and to the STS audience (aud).
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Least privilege: read-only access to a single S3 prefix holding the RAG corpus.
data "aws_iam_policy_document" "permissions" {
  statement {
    sid       = "ListCorpusPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.corpus_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.corpus_prefix}/*"]
    }
  }

  statement {
    sid       = "ReadCorpusObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.corpus_bucket}/${var.corpus_prefix}/*"]
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.role_name}-corpus-read"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}
