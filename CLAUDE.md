# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [Hugo](https://gohugo.io/) static site (source for wardtalks.com), using the `bootstrap-bp-hugo-theme` theme as a git submodule. Content is Brian's personal how-to/tutorial blog.

## Setup

The theme lives in `themes/bootstrap-bp-hugo-theme` as a git submodule and is **not checked out by default**. Initialize it before running Hugo locally:

```
git submodule update --init --recursive
```

`flake.nix` provides a dev shell with `git`, `hugo`, `awscli2`, and `awsume` (`nix develop` to enter it).

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

`config.toml` defines a Hugo Cloud Deploy target (`[[deployment.targets]]`) pushing to an S3 bucket (`s3://wardtalks.com`) fronted by CloudFront, invalidated via `cloudFrontDistributionID`. Deploy with `hugo deploy` (requires AWS credentials). Cache-control rules differ for hashed static assets (JS/CSS/fonts: 1 year) vs. images vs. HTML/XML/JSON (short-lived, gzip'd).

