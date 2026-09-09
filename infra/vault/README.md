# Vault Plugin Deployment Policy

`plugin-deployer.hcl`은 Factory가 생성한 Custom Plugin을 Vault Catalog에 등록하고 `factory-lab/*` 아래에 mount하기 위한 **예제 정책**입니다.

## 허용 범위

- `sys/plugins/catalog/*`: Custom Plugin catalog 등록·조회·삭제
- `sys/mounts/factory-lab/*`: Secret/Database Plugin mount 관리
- `sys/auth/factory-lab/*`: Auth Plugin mount 관리
- mount 목록 조회

## 적용 예시

```bash
vault policy write vault-plugin-factory-deployer infra/vault/plugin-deployer.hcl
```

실환경에서는 Factory 전용 AppRole/JWT/OIDC workload identity 등에 이 Policy를 연결하고, Root Token은 사용하지 않습니다.

## 운영 적용 전 검토

- Namespace별 `sys/` 경로 범위
- 실제 사용할 mount prefix
- `delete`와 `sudo` 권한 필요성
- Plugin registration과 mount 변경을 서로 다른 identity로 분리할지 여부
- Change approval 및 rollback 절차

예제의 `factory-lab/*`를 운영 경로로 그대로 사용하지 말고 조직의 namespace/mount 설계에 맞게 좁혀서 적용하세요.
