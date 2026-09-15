# This zone is shared: it also holds records for sibling projects
# (serverless.wardtalks.com, sobriety.wardtalks.com) that this repo does not
# own and must not manage. Only the apex records for wardtalks.com itself —
# the site this repo deploys — are declared here. Sibling project repos that
# want a *.wardtalks.com record of their own should look this zone up with
# `data "aws_route53_zone"` rather than this repo creating it for them,
# mirroring how the `aws` repo owns IAM users and project repos look them up.
resource "aws_route53_zone" "wardtalks" {
  name    = "wardtalks.com"
  comment = "HostedZone created by Route53 Registrar"
}

resource "aws_route53_record" "wardtalks_a" {
  zone_id = aws_route53_zone.wardtalks.zone_id
  name    = "wardtalks.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.wardtalks.domain_name
    zone_id                = aws_cloudfront_distribution.wardtalks.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "wardtalks_aaaa" {
  zone_id = aws_route53_zone.wardtalks.zone_id
  name    = "wardtalks.com"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.wardtalks.domain_name
    zone_id                = aws_cloudfront_distribution.wardtalks.hosted_zone_id
    evaluate_target_health = false
  }
}

# DNS validation record for the apex ACM certificate (see locals in
# cloudfront.tf). The certificate itself is managed outside this repo, but
# this validation record lives in a zone this repo owns.
resource "aws_route53_record" "wardtalks_acm_validation" {
  zone_id = aws_route53_zone.wardtalks.zone_id
  name    = "_dcd6b891f95c86ec1601cc18fa3a7861.wardtalks.com"
  type    = "CNAME"
  ttl     = 300
  records = ["_a6d0fac5d15c3b4fbbdfd8f3f1355fb8.nhqijqilxf.acm-validations.aws."]
}
