# The ACM certificate is managed outside this repo (it also covers
# sobriety.wardtalks.com, a sibling project) and is only referred to here by
# ARN, in locals.
#
# The Lambda@Edge function (see lambda.tf) rewrites directory-style requests
# (e.g. "/posts/foo/") to "/posts/foo/index.html" at origin-request time.
# That rewrite currently does all the work default_root_object would
# normally do — default_root_object is unset below, matching the live
# distribution — so removing this Lambda would very likely break every page,
# including "/", not just subdirectories. Confirm that before ever detaching it.
locals {
  wardtalks_acm_certificate_arn = "arn:aws:acm:us-east-1:475727583260:certificate/d98285d2-01ce-4318-a9ee-7af1130f073b"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "cors_s3_origin" {
  name = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_origin_access_identity" "wardtalks" {
  comment = "access-identity-wardtalks.com.s3.amazonaws.com"
}

resource "aws_cloudfront_distribution" "wardtalks" {
  enabled         = true
  aliases         = ["wardtalks.com"]
  price_class     = "PriceClass_200"
  http_version    = "http2"
  is_ipv6_enabled = true

  origin {
    # The distribution predates regional S3 endpoints becoming the default;
    # it still points at the legacy global endpoint. Left as a literal
    # (rather than aws_s3_bucket.wardtalks.bucket_regional_domain_name) to
    # avoid an unnecessary origin change on apply.
    domain_name = "wardtalks.com.s3.amazonaws.com"
    origin_id   = "S3-wardtalks.com"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.wardtalks.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id           = "S3-wardtalks.com"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = false
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.cors_s3_origin.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.hugo_url_rewrite.qualified_arn
      include_body = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.wardtalks_acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
