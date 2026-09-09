# Architecture

## Responsibility boundary

Vault Plugin Factory is the build and validation boundary for custom Vault plugins. It does not own end-user approval workflows or long-lived Vault administration credentials.

```mermaid
flowchart LR
  P[Portal / CLI / CI] --> R[Requirements Interview]
  R --> C[Template Catalog]
  C --> G[Scaffold Generator]
  G --> S[Security Review + Dry Run]
  S --> B[Isolated Build / Test]
  B --> A[Verified Artifact]
  A --> D[Distribution Adapter]
  D --> V[Vault Nodes]
  V --> M[Plugin Registration / Mount]
```

## Core modules

- `catalog.ts`: template metadata, scaffolding, dry-run and validation plans
- `factory-requirements.ts`: structured requirements interview
- `factory-assistant.ts`: rules/Ollama assistance and bounded repair support
- `factory-build-service.ts`: static or CodeBuild execution, S3 artifact handling
- `factory-artifact.ts`: artifact evidence and SHA-256 verification
- `plugin-distributor.ts`: mock/SSM binary distribution
- `plugin-mount-guard.ts`: live-inventory guard before managed mount operations

## Trust boundaries

### Caller

The caller owns user identity, approval, job persistence, and business workflow state.

### Factory

The Factory owns template selection, source generation, validation, build attempts, artifact integrity evidence, and distribution preparation.

### Build environment

The build environment should have only the permissions required to fetch dependencies, run the build, and store artifacts. It should not receive Vault Root credentials.

### Vault deployment

Plugin registration and mount operations should use a separately authorized deployment identity. Distribution of a binary does not by itself authorize registration or mount changes.

## Extraction note

The original Portal implementation contains `factory-job-recovery.ts`, which depends directly on the Portal store and audit interfaces. That module is intentionally left outside the standalone core. A future Portal-to-Factory API can persist job state without reintroducing a direct package dependency.
