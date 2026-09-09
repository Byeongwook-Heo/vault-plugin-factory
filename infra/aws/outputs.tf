output "artifact_bucket_name" {
  description = "S3 bucket used for Factory source, result, and binary artifacts."
  value       = aws_s3_bucket.artifacts.id
}

output "codebuild_project_name" {
  description = "CodeBuild project name expected by FactoryBuildService."
  value       = aws_codebuild_project.factory.name
}

output "operator_policy_arn" {
  description = "IAM policy to attach to the Factory runtime identity."
  value       = aws_iam_policy.operator.arn
}
