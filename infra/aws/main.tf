data "aws_partition" "current" {}

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${var.name_prefix}-artifacts-"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-factory-builds"
    status = "Enabled"

    filter {
      prefix = "factory-builds/"
    }

    expiration {
      days = var.artifact_expiration_days
    }
  }
}

data "aws_iam_policy_document" "artifact_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  policy = data.aws_iam_policy_document.artifact_bucket.json
}

resource "aws_cloudwatch_log_group" "build" {
  name              = "/codebuild/${var.name_prefix}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name_prefix        = "${var.name_prefix}-build-"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid = "BuildLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.build.arn}:*"]
  }

  statement {
    sid = "ArtifactBucketMetadata"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.artifacts.arn]
  }

  statement {
    sid = "ArtifactObjects"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.artifacts.arn}/factory-builds/*"]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "factory-build"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_codebuild_project" "factory" {
  name                   = var.name_prefix
  description            = "Credential-free isolated Go build runner for Vault custom plugins."
  service_role           = aws_iam_role.codebuild.arn
  build_timeout          = 15
  queued_timeout         = 15
  concurrent_build_limit = 2

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.build.name
      stream_name = "build"
    }
  }

  source {
    type = "NO_SOURCE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        install:
          runtime-versions:
            golang: 1.22
        build:
          commands:
            - |
              set +e
              WORK_DIR=/tmp/factory-source
              SOURCE_ZIP=/tmp/factory-source.zip
              BINARY=/tmp/$FACTORY_COMMAND
              LOG=/tmp/factory-build.log
              RESULT=/tmp/factory-result.json
              STATUS=pass
              FORMAT_STATUS=skipped
              TIDY_STATUS=skipped
              TEST_STATUS=skipped
              BUILD_STATUS=skipped
              SHA256=""
              rm -rf "$WORK_DIR" "$SOURCE_ZIP" "$BINARY" "$LOG" "$RESULT"
              mkdir -p "$WORK_DIR"
              : > "$LOG"

              if aws s3 cp "s3://$FACTORY_BUCKET/$FACTORY_SOURCE_KEY" "$SOURCE_ZIP" --only-show-errors >>"$LOG" 2>&1 && unzip -q "$SOURCE_ZIP" -d "$WORK_DIR" >>"$LOG" 2>&1; then
                cd "$WORK_DIR" || STATUS=fail

                if find . -type f -name '*.go' -print0 | xargs -0 -r gofmt -w >>"$LOG" 2>&1; then
                  FORMAT_STATUS=pass
                else
                  FORMAT_STATUS=fail
                  STATUS=fail
                fi

                if go mod tidy >>"$LOG" 2>&1; then
                  TIDY_STATUS=pass
                else
                  TIDY_STATUS=fail
                  STATUS=fail
                fi

                if go test ./... >>"$LOG" 2>&1; then
                  TEST_STATUS=pass
                else
                  TEST_STATUS=fail
                  STATUS=fail
                fi

                if GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -o "$BINARY" "./cmd/$FACTORY_PLUGIN_NAME" >>"$LOG" 2>&1; then
                  BUILD_STATUS=pass
                  SHA256=$(sha256sum "$BINARY" | awk '{print $1}')
                else
                  BUILD_STATUS=fail
                  STATUS=fail
                fi

                if [ "$STATUS" = pass ]; then
                  if ! aws s3 cp "$BINARY" "s3://$FACTORY_BUCKET/$FACTORY_ARTIFACT_KEY" --only-show-errors >>"$LOG" 2>&1; then
                    BUILD_STATUS=fail
                    STATUS=fail
                    SHA256=""
                  fi
                fi
              else
                STATUS=fail
              fi

              DIAGNOSTICS=$(tail -c 16000 "$LOG" | base64 -w 0)
              jq -n \
                --arg status "$STATUS" \
                --arg diagnostics_base64 "$DIAGNOSTICS" \
                --arg sha256 "$SHA256" \
                --arg format_status "$FORMAT_STATUS" \
                --arg tidy_status "$TIDY_STATUS" \
                --arg test_status "$TEST_STATUS" \
                --arg build_status "$BUILD_STATUS" \
                '{status: $status, diagnostics_base64: $diagnostics_base64, sha256: $sha256, format_status: $format_status, tidy_status: $tidy_status, test_status: $test_status, build_status: $build_status}' > "$RESULT"
              aws s3 cp "$RESULT" "s3://$FACTORY_BUCKET/$FACTORY_RESULT_KEY" --only-show-errors
              exit 0
    BUILDSPEC
  }

  depends_on = [aws_iam_role_policy.codebuild]
}

data "aws_iam_policy_document" "operator" {
  statement {
    sid       = "StartFactoryBuild"
    actions   = ["codebuild:StartBuild"]
    resources = [aws_codebuild_project.factory.arn]
  }

  statement {
    sid       = "ReadFactoryBuild"
    actions   = ["codebuild:BatchGetBuilds"]
    resources = ["*"]
  }

  statement {
    sid = "ArtifactBucketMetadata"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.artifacts.arn]
  }

  statement {
    sid = "ArtifactObjects"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.artifacts.arn}/factory-builds/*"]
  }

  dynamic "statement" {
    for_each = length(var.vault_instance_arns) > 0 ? [1] : []

    content {
      sid     = "DistributePluginWithSsm"
      actions = ["ssm:SendCommand"]
      resources = concat(
        ["arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::document/AWS-RunShellScript"],
        var.vault_instance_arns
      )
    }
  }

  statement {
    sid       = "ReadPluginDistribution"
    actions   = ["ssm:GetCommandInvocation"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "operator" {
  name_prefix = "${var.name_prefix}-operator-"
  description = "Permissions for the Vault Plugin Factory service to build and distribute verified artifacts."
  policy      = data.aws_iam_policy_document.operator.json
}
