variable "aws_region" {
  description = "AWS region used by the Factory build infrastructure."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for Factory AWS resources."
  type        = string
  default     = "vault-plugin-factory"
}

variable "artifact_expiration_days" {
  description = "Days before Factory source/results/artifacts expire from S3."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "CloudWatch log retention for CodeBuild."
  type        = number
  default     = 30
}

variable "vault_instance_arns" {
  description = "Vault EC2 instance ARNs allowed as SSM SendCommand targets."
  type        = list(string)
  default     = []
}
