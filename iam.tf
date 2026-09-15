# Mechanism: add any user in var.deployer_usernames to wardtalks-deployers.
# Users themselves are owned by the aws repo; this repo only looks them up.
data "aws_iam_user" "deployers" {
  for_each  = toset(var.deployer_usernames)
  user_name = each.value
}

resource "aws_iam_group" "wardtalks_deployers" {
  name = "wardtalks-deployers"
}

resource "aws_iam_group_membership" "wardtalks_deployers" {
  name  = "wardtalks-deployers-membership"
  group = aws_iam_group.wardtalks_deployers.name
  users = [for u in data.aws_iam_user.deployers : u.user_name]
}

# The group only grants sts:AssumeRole; wardtalks_deploy holds the actual
# permissions, mirroring the aws-admin pattern in the aws repo.
resource "aws_iam_group_policy" "wardtalks_deployers_assume_role" {
  name  = "wardtalks-deploy-assume-role"
  group = aws_iam_group.wardtalks_deployers.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.wardtalks_deploy.arn
      }
    ]
  })
}

resource "aws_iam_role" "wardtalks_deploy" {
  name = "wardtalks-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "wardtalks_deploy_s3" {
  name = "wardtalks-deploy-s3"
  role = aws_iam_role.wardtalks_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.wardtalks.arn,
          "${aws_s3_bucket.wardtalks.arn}/*",
        ]
      }
    ]
  })
}

# hugo deploy (config.toml's [[deployment.targets]]) invalidates CloudFront
# after syncing, so the deploy role needs this in addition to S3 access.
resource "aws_iam_role_policy" "wardtalks_deploy_cloudfront" {
  name = "wardtalks-deploy-cloudfront"
  role = aws_iam_role.wardtalks_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
        ]
        Resource = aws_cloudfront_distribution.wardtalks.arn
      }
    ]
  })
}

# Lets the deploy identity push code changes to the existing
# hugo-url-rewrite Lambda@Edge function (see lambda.tf) without going
# through terraform apply as admin/terraform. Deliberately excludes
# CreateFunction/DeleteFunction — creating or removing the function stays a
# Terraform-only, admin-level operation.
resource "aws_iam_role_policy" "wardtalks_deploy_lambda" {
  name = "wardtalks-deploy-lambda"
  role = aws_iam_role.wardtalks_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion",
        ]
        Resource = aws_lambda_function.hugo_url_rewrite.arn
      }
    ]
  })
}
