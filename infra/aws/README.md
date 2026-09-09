# AWS Factory Build Infrastructure

이 Terraform 구성은 Vault Plugin Factory의 빌드·아티팩트·배포 경계만 생성합니다. Security Portal의 VPC, ECS, RDS 또는 사용자 승인 워크플로에는 의존하지 않습니다.

## 생성 리소스

- Private S3 artifact bucket
- Factory artifact 30일 기본 lifecycle
- CloudWatch CodeBuild log group
- 격리 Go CodeBuild project
- CodeBuild service role
- Factory runtime에 attach할 operator IAM policy
- 선택적으로 지정한 Vault EC2 instance ARN에 대한 SSM SendCommand 권한

## 사용

```bash
terraform init
terraform plan -var='aws_region=ap-northeast-2'
terraform apply -var='aws_region=ap-northeast-2'
```

Vault 노드로 SSM 배포까지 사용할 경우:

```hcl
vault_instance_arns = [
  "arn:aws:ec2:ap-northeast-2:123456789012:instance/i-0123456789abcdef0"
]
```

Apply 후 출력되는 값을 Factory runtime 설정에 연결합니다.

- `artifact_bucket_name` → Factory artifact bucket
- `codebuild_project_name` → FactoryBuildService CodeBuild project
- `operator_policy_arn` → Factory runtime IAM role/user에 attach

## 보안 참고

- CodeBuild role에는 Vault credential을 부여하지 않습니다.
- S3 artifact는 TLS 전송을 강제하고 public access를 차단합니다.
- Factory runtime과 Vault node IAM role을 분리합니다.
- Vault node가 S3 artifact를 직접 읽어야 한다면 별도 최소권한 `s3:GetObject` 정책을 노드 역할에 구성해야 합니다.
- 예제는 `linux/arm64` Plugin binary 빌드를 기준으로 합니다.
