# Vault Plugin Factory

[한국어](README.md) · [English](README.en.md)

A standalone Factory for designing, generating, validating, building, and preparing deployment artifacts for **HashiCorp Vault Custom Auth / Secrets / Database Plugins**.

This codebase is extracted from the Plugin Factory capabilities that were previously embedded in `vault-security-portal`.

## Why this is a separate project

`vault-security-portal` owns credential request, approval, issuance, revocation, and audit workflows. Vault Plugin Factory owns the Plugin lifecycle: **design → generation → validation → artifact → distribution**. Separating the two allows independent deployment, upgrades, and privilege boundaries between a user-facing portal and a plugin build pipeline.

## Capabilities

### Plugin Catalog

- Auth / Secret / Database Plugin templates
- official, partner, learning, and community source categories
- plugin type, default mount path, command, version, and guardrail metadata
- extension templates such as GitHub PAT rotation

### Requirements Interview

Structured collection of:

- target system
- authentication method
- API base path
- TTL
- rotation and revoke strategies
- mount path
- environment (dev / staging / prod)

Rules-based interviews are the default; Ollama-assisted flows can be enabled when configured.

### Scaffold Generation

Generate plugin source and operational artifacts from requirements and templates, including:

- Go plugin scaffolds
- HCL / Markdown / Makefile support files
- dry-run plans
- build/test plans
- rollback plans
- security-review findings

### Build & Auto-repair

- static or isolated AWS CodeBuild execution
- `fmt`, `tidy`, `test`, and `build` validation
- bounded repair attempts after build failures
- S3 artifact storage
- SHA-256 artifact integrity verification

### Artifact Distribution

Verified binaries can be distributed to Vault nodes through AWS SSM. The distributor downloads the S3 artifact, verifies SHA-256, and installs it into the configured Vault plugin directory.

### Mount Guard

The guard checks live Vault inventory before treating a mount as managed:

- external plugin source
- expected Auth/Secret mount kind
- matching plugin name and mount path
- matching Vault plugin-catalog entry

## Flow

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
Auto Repair (when needed)
    ↓
SHA-256 Verified Artifact
    ↓
S3 Artifact
    ↓
SSM Distribution
    ↓
Vault Plugin Registration / Mount
```

## Repository structure

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
└── Shared Plugin Factory and Vault inventory types

infra/
├── aws/       # S3 artifacts, CodeBuild, Factory runtime IAM policy
└── vault/     # least-privilege example for plugin catalog/mount operations
```

## Getting started

### Requirements

- Node.js 24 recommended for `pnpm 11.7.0`
- pnpm 11.x
- Go toolchain or an AWS CodeBuild environment for plugin builds
- AWS S3 / CodeBuild / SSM permissions and Vault plugin-directory configuration for real distribution

```bash
pnpm install
pnpm typecheck
pnpm test
pnpm build
```

## Deployment assets

- [AWS Factory Build Infrastructure](infra/aws/README.md): S3, CodeBuild, and Factory runtime IAM/SSM permissions
- [Vault Plugin Deployment Policy](infra/vault/README.md): example policy for plugin catalog registration and `factory-lab/*` mounts
- [Architecture](docs/ARCHITECTURE.md): caller, Factory, build environment, and Vault deployment trust boundaries

## Operating modes

The Factory core is independent from the Portal UI and can be consumed as a library/service layer.

- Requirements: `rules` / `ollama`
- Assistant: `rules` / `ollama`
- Build: `static` / `codebuild`
- Distribution: `mock` / `ssm`

Production Vault registration and mount operations should be performed through a separately authorized deployment adapter or an approved calling application.

## Responsibility boundaries

| Project | Responsibility |
| --- | --- |
| `vault-plugin-factory` | templates, generation, build, artifact, distribution, guardrails |
| `vault-security-portal` | user requests, approvals, credential lifecycle, audit, Factory UI/client |
| `hashicorp-enterprise-aws-lab` | executable AWS/Vault/Terraform infrastructure labs |
| `Hashicorp-` | product guides and operational runbooks |

## Security principles

- Do not store a Vault Root Token in the build service.
- Keep generated source and build artifacts separate.
- Verify artifact SHA-256 before distribution.
- Separate build permissions from Vault runtime permissions.
- Restrict plugin distribution, registration, and mount operations with least privilege.
- Re-check live inventory before changing or removing a mount.
- Do not treat development Mock/Rules results as production validation evidence.

## Extraction scope

Portal-specific state-recovery logic such as `factory-job-recovery` is intentionally excluded from the Factory core because it directly depends on the Portal store. Job orchestration and persistence belong to the calling application; the Factory focuses on generation, builds, artifacts, and distribution.

## Related projects

- [Vault Security Portal](https://github.com/Byeongwook-Heo/vault-security-portal)
- [HashiCorp Enterprise AWS Lab](https://github.com/Byeongwook-Heo/hashicorp-enterprise-aws-lab)
- [Project Catalog](https://github.com/Byeongwook-Heo/project-catalog)

## Scope and limitations

This project is a lab and extension foundation for Vault custom plugin development and validation. Before production use, independently verify source review, Vault-version compatibility, Plugin API expectations, permissions, TLS, build supply-chain controls, and rollback procedures.
