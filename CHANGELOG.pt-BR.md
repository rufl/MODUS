# Changelog do MODUS — Português (Brasil)

> **Documentation status: maintained reference.** Este arquivo resume as mudanças públicas atuais em português. O histórico completo e canônico continua em [`CHANGELOG.md`](CHANGELOG.md).

**Idiomas:** [English](CHANGELOG.md) · [Português (Brasil)](CHANGELOG.pt-BR.md)
**Atualizado:** 29 de setembro de 2026

## Não lançado

### Documentação

- Atualizados README, estado atual, contrato de verdade, matriz de limites, bundle de evidências, roadmap, backlog, setup, hardware, troubleshooting e testes em inglês.
- Adicionada navegação e tradução brasileira para as referências mantidas de maior uso.
- Claims atuais agora apontam para CI `36588760158`, commit `701ead47`, dogfood autenticado e hashes ativos; snapshots históricos continuam datados.

### Distribuição e segurança

- `tools/deploy_overzeer_fleet.sh` agora aceita endpoints HTTPS e arquivos de token separados para DDJARIN e CHOPPER, mantendo o modo legado de endpoint/token único.
- Regressão de forwarding, package/inventory/validator/staging/cleanup, ZTASH e toolchain-lock passam.
- OVERZEER completo e ZTASH enxuto são validados sem assinatura; dogfood autenticado não é release público.

### Dogfood atual

- Build GUI: `6d0f781743e2dac90f0f33cd2f32c1f8c33b1f79`.
- DDJARIN Windows: `45fa1f81a7c154ef971daf0557efe3128dab1ad11cd730e36a92507518d77363`.
- CHOPPER Linux: `da865fa1a9f052eabcc8addf70402d660ddb984332a5c12a4f131b689b645667`.
- O pipeline CI `36588760158` e o quality run `36588760149` passaram no commit `701ead4758c6e23f67a31e22587a7ef38166faff`.

## Gates ainda abertos

Assinatura, instalador, publicação pública, execução Windows nativa, WAN ENet independente, Steam de duas contas, Workshop real, editor gráfico exportado, gameplay manual revisado, aprovação audiovisual/pacing e promoção para `1.0` continuam pendentes. Consulte [`docs/pt-BR/CURRENT_STATUS.md`](docs/pt-BR/CURRENT_STATUS.md) e [`docs/pt-BR/KNOWN_LIMITS_MATRIX.md`](docs/pt-BR/KNOWN_LIMITS_MATRIX.md).
