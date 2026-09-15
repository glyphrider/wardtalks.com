# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [Hugo](https://gohugo.io/) static site (source for wardtalks.com), using the `bootstrap-bp-hugo-theme` theme as a git submodule. Content is Brian's personal how-to/tutorial blog.

## Setup

The theme lives in `themes/bootstrap-bp-hugo-theme` as a git submodule and is **not checked out by default**. Initialize it before running Hugo locally:

```
git submodule update --init --recursive
```

`flake.nix` provides a dev shell with `git`, `hugo`, `awscli2`, `awsume`, and `terraform` (`nix develop` to enter it; `terraform` needs `config.allowUnfree = true` since it's BSL-licensed).

## Common commands

- `hugo server -D` — run the local dev server with drafts included
- `hugo` — build the static site to `public/`
- `hugo new posts/<name>.md` — create a new post from `archetypes/default.md`

There is no lint/test suite; this is a content-only static site repo.

## Content structure

- Posts live under `content/posts/`. A post is either a single `.md` file, or a **page bundle**: a directory containing `index.md` plus co-located assets (e.g. `content/posts/new_computer/index.md` with `new_computer_cover.jpg`). Prefer the page-bundle form when a post has its own images.
- Front matter is minimal YAML: `title`, `date`, `draft`. Set `draft: false` to publish.
- Images not part of a page bundle go in `static/img/` and are referenced as absolute paths, e.g. `![alt](/img/foo.png)`.
- `static/software/` holds miscellaneous downloadable files referenced from posts.

## Deployment

`config.toml` defines a Hugo Cloud Deploy target (`[[deployment.targets]]`) pushing to an S3 bucket (`s3://wardtalks.com`) fronted by CloudFront, invalidated via `cloudFrontDistributionID`. Deploy with `hugo deploy`, using the `wardtalks` AWS profile (assumes `wardtalks-deploy`, scoped to S3 read/write on this bucket plus CloudFront invalidation — see Infrastructure below). Cache-control rules differ for hashed static assets (JS/CSS/fonts: 1 year) vs. images vs. HTML/XML/JSON (short-lived, gzip'd).

## Infrastructure (Terraform)

This repo owns and manages the AWS infrastructure for the live site — the S3 bucket, CloudFront distribution, Route53 apex records, and deploy access — following the cross-project IAM convention from the sibling `aws` repo (that repo owns IAM *users* and the `terraform`/`aws-admin` roles; this repo owns its own deploy *group*/*role* and looks users up by name). All of it predates this repo and was imported, not created fresh — `terraform plan` shows zero drift against the live resources.

- **`main.tf`** — provider (`us-east-2`, the bucket's region) + `data.aws_caller_identity.current`.
- **`s3.tf`** — the `wardtalks.com` bucket: private (public access fully blocked, SSE-S3 encryption), readable only by CloudFront via a legacy Origin Access Identity (predates the OAC pattern used by sibling sites).
- **`cloudfront.tf`** — the distribution (custom domain `wardtalks.com`) and its OAI. The ACM certificate is managed outside this repo (it also covers `sobriety.wardtalks.com`, a sibling project — do not treat it as exclusively ours) and referenced only by ARN, in `locals`. The Lambda@Edge association points at `aws_lambda_function.hugo_url_rewrite` (see `lambda.tf`) — **that Lambda matters more than it looks**: `default_root_object` is unset on the distribution, and the origin is the S3 *REST* endpoint (no native index-document support), so the Lambda is doing 100% of the "/" → "/index.html" and "/posts/foo/" → "/posts/foo/index.html" resolution — including the bare root. Don't detach it without replacing that behavior first.
- **`route53.tf`** — the `wardtalks.com` hosted zone and only its apex `A`/`AAAA` (alias to CloudFront) and ACM-validation `CNAME` records. The zone is **shared**: it also holds `serverless.wardtalks.com` and `sobriety.wardtalks.com` records for unrelated sibling projects that this repo deliberately does not import or manage. A sibling project repo wanting its own `*.wardtalks.com` record should look this zone up with `data "aws_route53_zone"` rather than this repo creating it for them — same lookup-not-create convention as IAM users in the `aws` repo.
- **`iam.tf`** — the deploy mechanism: `var.deployer_usernames` (in `variables.tf`) lists which IAM users (owned by the `aws` repo) get added to `wardtalks-deployers`, which can only assume `wardtalks-deploy` — group→role indirection, same as `aws-admin` and sibling `*-deploy` roles. `wardtalks-deploy` is scoped to: S3 read/write on this bucket, CloudFront invalidation on this distribution, and updating (not creating/deleting) the `hugo-url-rewrite` function's code/config specifically. That last grant means the Lambda *can* be pushed to directly with the `wardtalks` profile, outside Terraform — if that ever happens, the next `terraform apply` will overwrite it back to whatever `lambda/hugo-url-rewrite/index.js` says, since Terraform still owns the function's declared state. Prefer `terraform apply` as the normal path; the direct-update permission exists for a lighter-weight deploy option, not to replace it.
- **`lambda.tf`** / **`lambda/hugo-url-rewrite/index.js`** — the URL-rewrite Lambda@Edge function itself, pulled from the live deployed code (it wasn't in any repo — created directly in the Lambda console in 2020, last published 2023) and brought under management here, including its console-generated execution role/policy. Must run in `us-east-1` regardless of everything else living in `us-east-2` (see the `aws.us_east_1` provider alias in `main.tf`) — Lambda@Edge is a us-east-1-only feature. `publish = true` means any code change auto-publishes a new numbered version and CloudFront's `lambda_function_association` picks it up via `qualified_arn`; $LATEST is never usable for Lambda@Edge.

State is local (`terraform.tfstate`, gitignored) — no remote backend. Run `terraform` as the `admin` or `terraform` AWS profile (see the `aws` repo; `terraform` needs `AWSLambda_FullAccess`, added alongside this Lambda), not as `wardtalks` (that role is scoped to deploys, not general infra changes — see the Lambda-update exception above).

