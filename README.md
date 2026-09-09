# Vault Plugin Factory

[한국어](README.md) · [English](README.en.md)

HashiCorp Vault용 **Custom Auth / Secrets / Database Plugin**을 템플릿 기반으로 설계하고, 요구사항 수집 → 코드 생성 → 검증 → 빌드 → 아티팩트 → 배포 준비까지 연결하는 독립 Factory 프로젝트입니다.

기존 `vault-security-portal`에 포함되어 있던 Plugin Factory 코어를 분리했으며, Portal은 사용자 요청·승인·감사와 Factory 호출을 담당하고 이 저장소는 Plugin 수명주기를 담당합니다.

## 주요 기능

- **Plugin Catalog** — Auth / Secret / Database 템플릿, 공식·파트너·학습·커뮤니티 분류, guardrail 메타데이터
- **Requirements Interview** — 대상 시스템, 인증 방식, API 경로, TTL, Rotation/Revoke 전략, Mount path, 환경 수집
- **Scaffold Generation** — Go Plugin 코드, HCL/Markdown/Makefile, Dry-run, Build/Test, Rollback, Security Review 생성
- **Build & Auto-repair** — AWS CodeBuild 기반 격리 빌드, `fmt`/`tidy`/`test`/`build`, 제한된 자동 복구
- **Artifact Verification** — S3 Artifact와 SHA-256 무결성 검증
- **Artifact Distribution** — AWS SSM을 통한 Vault 노드 배포
- **Mount Guard** — live Vault inventory와 Plugin Catalog를 비교해 관리 가능한 외부 Plugin Mount만 식별

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
S3 / SSM Distribution
    ↓
Vault Plugin Registration / Mount
```

## 프로젝트 구조

```text
src/
├── index.ts
├── types.ts
├── plugin-factory/
│   ├── catalog.ts
│   ├── expansion-catalog.ts
│   ├── factory-artifact.ts
│   ├── factory-assistant.ts
│   ├── factory-build-service.ts
│   ├── factory-requirements.ts
│   ├── github-pat-rotation-template.ts
│   └── plugin-distributor.ts
└── vault/
    └── plugin-mount-guard.ts

test/                 # Factory 코어 단위/회귀 테스트
infra/aws/            # S3 Artifact, CodeBuild, runtime IAM/SSM 예제
infra/vault/          # Plugin Catalog/Mount 최소권한 정책 예제
docs/ARCHITECTURE.md  # Caller, Factory, Build, Vault 신뢰 경계
```

루트 패키지는 `@vault-plugin-factory/core`이며 Portal 전용 Store나 UI에 의존하지 않습니다. Portal에 종속된 `factory-job-recovery` 같은 orchestration/영속화 로직은 이 저장소의 책임에서 제외합니다.

## 시작하기

### 요구사항

- Node.js 24 권장 (`pnpm 11.7.0` 호환)
- pnpm 11.x
- 생성된 Vault Plugin 자체 빌드에는 Go toolchain 또는 AWS CodeBuild
- 실제 배포에는 AWS S3 / CodeBuild / SSM 권한과 Vault Plugin Directory 구성

```bash
pnpm install
pnpm typecheck
pnpm test
pnpm build
```

빌드 결과는 `dist/`에 생성됩니다.

## 다른 프로젝트에서 사용

이 저장소는 독립 패키지이므로 특정 Git commit에 고정해 사용할 수 있습니다.

```json
{
  "dependencies": {
    "@vault-plugin-factory/core": "github:Byeongwook-Heo/vault-plugin-factory#<commit-sha>"
  }
}
```

운영/연동 프로젝트에서는 `main`을 직접 따라가기보다 검증한 commit 또는 release/tag에 고정하는 것을 권장합니다.

## 배포 자산

- [AWS Factory Build Infrastructure](infra/aws/README.md) — S3, CodeBuild, Factory runtime IAM/SSM
- [Vault Plugin Deployment Policy](infra/vault/README.md) — Plugin Catalog 등록 및 `factory-lab/*` Mount 정책 예제
- [Architecture](docs/ARCHITECTURE.md) — Caller, Factory, Build 환경, Vault 배포 경계

## 실행 모드

- Requirements: `rules` / `ollama`
- Assistant: `rules` / `ollama`
- Build: `static` / `codebuild`
- Distribution: `mock` / `ssm`

실제 Vault 등록 및 Mount는 승인된 deployment adapter 또는 호출 애플리케이션에서 수행하도록 경계를 분리하는 것을 권장합니다.

## 프로젝트별 책임

| 프로젝트 | 책임 |
| --- | --- |
| `vault-plugin-factory` | Plugin template, generation, build, artifact, distribution, guardrail |
| `vault-security-portal` | 사용자 요청, 승인, 자격증명 수명주기, 감사, Factory 호출/UI |
| `hashicorp-enterprise-aws-lab` | 실행 가능한 AWS/Vault/Terraform 인프라 실습 |
| `Hashicorp-` | 제품 가이드와 운영 Runbook |

## 보안 원칙

- Build 서비스에 Vault Root Token을 저장하지 않습니다.
- 생성 Source와 Build Artifact를 분리합니다.
- Artifact는 SHA-256 검증 후 배포합니다.
- Build 권한과 Vault Runtime 권한을 분리합니다.
- Plugin 등록·배포·Mount는 최소권한으로 제한합니다.
- 기존 Mount 변경/삭제 전에 live inventory를 다시 확인합니다.
- Mock/Rules 결과를 운영 검증 결과로 간주하지 않습니다.

## 관련 프로젝트

- [Vault Security Portal](https://github.com/Byeongwook-Heo/vault-security-portal)
- [HashiCorp Enterprise AWS Lab](https://github.com/Byeongwook-Heo/hashicorp-enterprise-aws-lab)
- [Project Catalog](https://github.com/Byeongwook-Heo/project-catalog)

## 범위와 제약사항

이 프로젝트는 Vault Custom Plugin 개발·검증을 위한 확장 기반입니다. 운영 적용 전 코드 리뷰, Vault 버전 및 Plugin API 호환성, 최소권한, TLS, 빌드 공급망, 롤백 절차를 별도로 검증해야 합니다.
