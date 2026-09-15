resource "aws_s3_bucket" "wardtalks" {
  bucket = "wardtalks.com"
}

resource "aws_s3_bucket_public_access_block" "wardtalks" {
  bucket = aws_s3_bucket.wardtalks.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "wardtalks" {
  bucket = aws_s3_bucket.wardtalks.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

# Predates the OAC-based bucket policy used by sibling sites; this bucket
# still authorizes the legacy CloudFront Origin Access Identity below.
resource "aws_s3_bucket_policy" "wardtalks" {
  bucket = aws_s3_bucket.wardtalks.id

  policy = jsonencode({
    Version = "2008-10-17"
    Id      = "PolicyForCloudFrontPrivateContent"
    Statement = [
      {
        Sid       = "1"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.wardtalks.id}" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.wardtalks.arn}/*"
      }
    ]
  })
}
