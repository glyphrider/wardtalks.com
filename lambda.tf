# The Lambda@Edge function CloudFront invokes on origin-request (see
# cloudfront.tf) to rewrite directory-style URIs to their index.html, since
# the S3 REST origin has no native index-document support and
# default_root_object only covers the bare "/" of the distribution. Source
# in lambda/hugo-url-rewrite/index.js; predates this repo (created 2020,
# last published 2023) and was pulled from the live function + console-
# generated execution role, then brought under management here via import.

data "archive_file" "hugo_url_rewrite" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/hugo-url-rewrite"
  output_path = "${path.module}/.terraform/archives/hugo-url-rewrite.zip"
}

resource "aws_iam_role" "hugo_url_rewrite" {
  name = "hugo-url-rewrite-role-7jgetjr6"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "edgelambda.amazonaws.com",
            "lambda.amazonaws.com",
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Console-generated copy of AWSLambdaBasicExecutionRole, scoped to this
# function's own log group rather than the AWS managed policy's "*".
resource "aws_iam_policy" "hugo_url_rewrite_logs" {
  name = "AWSLambdaBasicExecutionRole-3e12fe79-bc28-4206-8f7b-8d42383f3062"
  path = "/service-role/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = [
          "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/hugo-url-rewrite:*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "hugo_url_rewrite_logs" {
  role       = aws_iam_role.hugo_url_rewrite.name
  policy_arn = aws_iam_policy.hugo_url_rewrite_logs.arn
}

resource "aws_lambda_function" "hugo_url_rewrite" {
  provider = aws.us_east_1

  function_name = "hugo-url-rewrite"
  role          = aws_iam_role.hugo_url_rewrite.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  architectures = ["x86_64"]
  timeout       = 3
  memory_size   = 128

  filename         = data.archive_file.hugo_url_rewrite.output_path
  source_code_hash = data.archive_file.hugo_url_rewrite.output_base64sha256

  # Lambda@Edge requires CloudFront to reference a specific published
  # version, never $LATEST — publish a new one whenever the code changes.
  publish = true
}
