# Vault Plugin Factory

[한국어](README.md) · [English](README.en.md)

HashiCorp Vault용 **Custom Auth / Secrets / Database Plugin**을 템플릿 기반으로 설계하고, 요구사항을 수집해 코드 스캐폴드를 생성한 뒤 빌드·검증·배포 준비까지 연결하는 Factory 프로젝트입니다.

이 프로젝트는 기존 `vault-security-portal`에 포함되어 있던 Plugin Factory 기능을 독립 프로젝트로 분리하기 위한 standalone 코드베이스입니다.

## 왜 별도 프로젝트인가

`vault-security-portal`은 자격증명 요청·승인·발급·폐기와 감사 흐름을 담당하고, Plugin Factory는 Vault Plugin의 **설계 → 생성 → 검증 → 아티팩트 → 배포** 수명주기를 담당합니다. 두 역할을 분리하면 Portal과 Plugin 빌드 파이프라인을 독립적으로 배포·업그레이드하고 권한 경계를 나눌 수 있습니다.

## 주요 기능

### 1. Plugin Catalog

- Vault Auth / Secret / Database Plugin 템플릿 카탈로그
- 공식·파트너·학습·커뮤니티 소스 구분
- Plugin 유형, 기본 mount path, command, version, guardrail 메타데이터
- GitHub PAT rotation 등 확장 템플릿

### 2. Requirements Interview

Plugin 생성 전에 아래 요구사항을 구조화합니다.

- 대상 시스템
- 인증 방식
- API base path
- TTL
- Rotation / Revoke 전략
- Mount path
- 환경(dev / staging / prod)

Rules 기반 인터뷰를 기본으로 사용하며, 구성 시 Ollama 기반 보조 흐름을 사용할 수 있습니다.

### 3. Scaffold Generation

요구사항과 선택한 Template을 기반으로 Plugin 코드와 운영 파일을 생성합니다.

- Go Plugin scaffold
- HCL / Markdown / Makefile 등 보조 파일
- Dry-run 변경 계획
- Build/Test 계획
- Rollback 계획
- Security review 결과

### 4. Build & Auto-repair

- Static 또는 AWS CodeBuild 기반 격리 빌드
- `fmt`, `tidy`, `test`, `build` 검증
- 실패 진단과 제한된 Auto-repair
- S3 Build Artifact 저장
- SHA-256 기반 Artifact 무결성 검증

### 5. Artifact Distribution

AWS SSM을 이용해 검증된 Plugin binary를 Vault 노드의 Plugin Directory로 배포할 수 있습니다.

배포 시 S3 Artifact를 내려받은 뒤 SHA-256을 검증하고 Vault 실행 계정 권한으로 설치합니다.

### 6. Mount Guard

실제 Vault Inventory와 비교해 다음 조건을 만족하는 Custom Plugin Mount만 관리 대상으로 인정합니다.

- External plugin인지
- 예상 Auth/Secret 유형과 일치하는지
- Plugin name과 mount path가 일치하는지
- Vault Plugin Catalog의 등록 상태와 연결되는지

## 처리 흐름

```text
Requirements
    ↓
Template / Catalog
    ↓
Scaffold Generation
    ↓
Dry Run + Security Review
    ↓
Build / Test
    ↓
Auto Repair (필요 시)
    ↓
SHA-256 Verified Artifact
    ↓
S3 Artifact
    ↓
SSM Distribution
    ↓
Vault Plugin Registration / Mount
```

## 프로젝트 구조

```text
apps/factory/
├── src/
│   ├── plugin-factory/
│   │   ├── catalog.ts
│   │   ├── expansion-catalog.ts
│   │   ├── factory-artifact.ts
│   │   ├── factory-assistant.ts
│   │   ├── factory-build-service.ts
│   │   ├── factory-requirements.ts
│   │   ├── github-pat-rotation-template.ts
│   │   └── plugin-distributor.ts
│   └── vault/
│       └── plugin-mount-guard.ts
└── test/

packages/shared/
└── Plugin Factory와 Vault inventory에 사용하는 공통 타입

infra/
├── aws/       # S3 Artifact, CodeBuild, Factory runtime IAM policy
└── vault/     # Plugin catalog/mount용 최소권한 정책 예제
```

## 시작하기

### 요구사항

- Node.js 24 권장 (`pnpm 11.7.0` 호환)
- pnpm 11.x
- Plugin 자체 빌드에는 Go toolchain 또는 AWS CodeBuild 환경
- 실제 배포에는 AWS S3 / CodeBuild / SSM 권한과 Vault Plugin Directory 접근 구성

### 설치

```bash
pnpm install
pnpm typecheck
pnpm test
pnpm build
```

## 배포 자산

- [AWS Factory Build Infrastructure](infra/aws/README.md): S3, CodeBuild, Factory runtime IAM/SSM 권한
- [Vault Plugin Deployment Policy](infra/vault/README.md): Plugin Catalog 등록과 `factory-lab/*` mount용 정책 예제
- [Architecture](docs/ARCHITECTURE.md): Caller, Factory, Build 환경, Vault 배포 경계

## 실행 모드

Factory 코어는 Portal UI와 분리되어 있으며 라이브러리/서비스 계층으로 사용할 수 있습니다.

- Requirements: `rules` / `ollama`
- Assistant: `rules` / `ollama`
- Build: `static` / `codebuild`
- Distribution: `mock` / `ssm`

실제 Vault 적용 단계는 운영 권한과 승인 절차를 갖춘 별도 deployment adapter 또는 Portal에서 호출하는 방식을 권장합니다.

## Vault Security Portal과의 역할 분리

| 프로젝트 | 책임 |
| --- | --- |
| `vault-plugin-factory` | Plugin template, generation, build, artifact, distribution, guardrail |
| `vault-security-portal` | 사용자 요청, 승인, 자격증명 수명주기, 감사, Factory 호출 UI |
| `hashicorp-enterprise-aws-lab` | 실행 가능한 AWS/Vault/Terraform 인프라 실습 |
| `Hashicorp-` | 제품 가이드와 운영 Runbook |

## 보안 원칙

- Vault Root Token을 Plugin 빌드 서비스에 저장하지 않습니다.
- 생성 코드와 Build Artifact를 분리합니다.
- Artifact는 SHA-256 검증 후 배포합니다.
- Build 환경과 Vault Runtime 권한을 분리합니다.
- Plugin 배포/등록/마운트는 최소권한 정책으로 제한합니다.
- 기존 Mount를 변경하거나 제거하기 전 live inventory를 다시 확인합니다.
- 개발용 Mock/Rules 모드 결과를 운영 검증 결과로 간주하지 않습니다.

## 현재 분리 범위

기존 Portal의 `factory-job-recovery`처럼 Portal Store와 직접 결합된 상태 복구 로직은 Factory 코어에서 제외했습니다. Job orchestration과 영속화는 호출 애플리케이션이 담당하고, Factory는 생성·빌드·아티팩트·배포 기능에 집중합니다.

## 관련 프로젝트

- [Vault Security Portal](https://github.com/Byeongwook-Heo/vault-security-portal)
- [HashiCorp Enterprise AWS Lab](https://github.com/Byeongwook-Heo/hashicorp-enterprise-aws-lab)
- [Project Catalog](https://github.com/Byeongwook-Heo/project-catalog)

## 범위와 제약사항

이 프로젝트는 Vault Custom Plugin 개발·검증을 위한 실습 및 확장 기반입니다. 생성된 Plugin을 운영 환경에 적용하기 전 코드 리뷰, Vault 버전 호환성, Plugin API, 권한 모델, TLS, 빌드 공급망과 복구 절차를 별도로 검증해야 합니다.
