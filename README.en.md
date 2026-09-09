# Vault Plugin Factory

[한국어](README.md) · [English](README.en.md)

A standalone Factory for designing **HashiCorp Vault Custom Auth / Secrets / Database Plugins** and carrying them through requirements → generation → validation → build → artifact → deployment preparation.

The Factory core was extracted from `vault-security-portal`. The Portal owns user requests, approvals, audit, and Factory invocation; this repository owns the plugin lifecycle.

## Capabilities

- **Plugin Catalog** — Auth / Secret / Database templates, official/partner/learning/community classifications, guardrail metadata
- **Requirements Interview** — target system, authentication, API path, TTL, rotation/revoke strategy, mount path, environment
- **Scaffold Generation** — Go plugin code, HCL/Markdown/Makefile assets, dry-run, build/test, rollback, security review
- **Build & Auto-repair** — isolated AWS CodeBuild execution, `fmt`/`tidy`/`test`/`build`, bounded repair attempts
- **Artifact Verification** — S3 artifact and SHA-256 integrity checks
- **Artifact Distribution** — Vault-node distribution through AWS SSM
- **Mount Guard** — live Vault inventory and plugin-catalog checks before treating an external mount as managed

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
S3 / SSM Distribution
    ↓
Vault Plugin Registration / Mount
```

## Repository structure

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

test/                 # Factory core unit/regression tests
infra/aws/            # S3 artifacts, CodeBuild, runtime IAM/SSM examples
infra/vault/          # least-privilege plugin catalog/mount policy example
docs/ARCHITECTURE.md  # caller, Factory, build, and Vault trust boundaries
```

The root package is `@vault-plugin-factory/core` and has no dependency on Portal-specific stores or UI. Portal-specific orchestration/persistence logic such as `factory-job-recovery` remains outside the Factory core.

## Getting started

### Requirements

- Node.js 24 recommended for `pnpm 11.7.0`
- pnpm 11.x
- Go toolchain or AWS CodeBuild for generated Vault plugin builds
- AWS S3 / CodeBuild / SSM permissions and Vault plugin-directory configuration for real distribution

```bash
pnpm install
pnpm typecheck
pnpm test
pnpm build
```

Build output is written to `dist/`.

## Consume from another project

Pin a validated Git commit when consuming the package directly from GitHub.

```json
{
  "dependencies": {
    "@vault-plugin-factory/core": "github:Byeongwook-Heo/vault-plugin-factory#<commit-sha>"
  }
}
```

For integrations and production-oriented use, pin a reviewed commit or release/tag instead of following `main` implicitly.

## Deployment assets

- [AWS Factory Build Infrastructure](infra/aws/README.md) — S3, CodeBuild, Factory runtime IAM/SSM
- [Vault Plugin Deployment Policy](infra/vault/README.md) — plugin catalog registration and `factory-lab/*` mount policy example
- [Architecture](docs/ARCHITECTURE.md) — caller, Factory, build environment, and Vault deployment boundaries

## Operating modes

- Requirements: `rules` / `ollama`
- Assistant: `rules` / `ollama`
- Build: `static` / `codebuild`
- Distribution: `mock` / `ssm`

Production Vault registration and mount operations should be performed through an approved deployment adapter or calling application.

## Responsibility boundaries

| Project | Responsibility |
| --- | --- |
| `vault-plugin-factory` | templates, generation, build, artifacts, distribution, guardrails |
| `vault-security-portal` | user requests, approvals, credential lifecycle, audit, Factory invocation/UI |
| `hashicorp-enterprise-aws-lab` | executable AWS/Vault/Terraform infrastructure labs |
| `Hashicorp-` | product guides and operational runbooks |

## Security principles

- Do not store a Vault Root Token in the build service.
- Keep generated source and build artifacts separate.
- Verify artifact SHA-256 before distribution.
- Separate build permissions from Vault runtime permissions.
- Restrict plugin registration, distribution, and mount operations with least privilege.
- Re-check live inventory before changing or removing an existing mount.
- Do not treat Mock/Rules results as production validation evidence.

## Related projects

- [Vault Security Portal](https://github.com/Byeongwook-Heo/vault-security-portal)
- [HashiCorp Enterprise AWS Lab](https://github.com/Byeongwook-Heo/hashicorp-enterprise-aws-lab)
- [Project Catalog](https://github.com/Byeongwook-Heo/project-catalog)

## Scope and limitations

This project is an extension foundation for Vault custom plugin development and validation. Before production use, independently verify source review, Vault-version and Plugin-API compatibility, least privilege, TLS, build supply-chain controls, and rollback procedures.
