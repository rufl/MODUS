# Changelog do MODUS — Português (Brasil)

> **Documentation status: maintained reference.** Este arquivo resume as mudanças públicas atuais em português. O histórico completo e canônico continua em [`CHANGELOG.md`](CHANGELOG.md).

**Idiomas:** [English](CHANGELOG.md) · [Português (Brasil)](CHANGELOG.pt-BR.md)
**Atualizado:** 30 de setembro de 2026

## Não lançado

### Documentação

- Atualizados README, estado atual, contrato de verdade, matriz de limites, bundle de evidências, roadmap, backlog, setup, hardware, troubleshooting e testes em inglês.
- Adicionada navegação e tradução brasileira para as referências mantidas de maior uso.
- Claims atuais agora apontam para CI `36588760158`, commit `701ead47`, dogfood autenticado do build `1f6d4faf4a80f4426f85f3a6f731689d756806ef` e hashes ativos; snapshots históricos continuam datados.

### Distribuição e segurança

- `tools/deploy_overzeer_fleet.sh` agora aceita endpoints HTTPS e arquivos de token separados para DDJARIN e CHOPPER, mantendo o modo legado de endpoint/token único.
- Regressão de forwarding, package/inventory/validator/staging/cleanup, ZTASH e toolchain-lock passam.
- OVERZEER completo e ZTASH enxuto são validados sem assinatura; dogfood autenticado não é release público.

### Dogfood atual

- Build de distribuição: `1f6d4faf4a80f4426f85f3a6f731689d756806ef`.
- DDJARIN Windows: `24a29d3eed0510d7993c99d9a97c7ff52358165485fac7f871b8874d50948d9b` / 141275566 bytes.
- CHOPPER Linux: `63171873e1b7ed3cc7cd190694064e35724a03f75a38830fb121626907618f64` / 131419549 bytes.
- O ZTASH manifest agora usa `size_bytes`, compatível com a ponte canônica do ZEER; preview e deployment autenticado passaram.
- O pipeline CI `36588760158` e o quality run `36588760149` passaram no commit `701ead4758c6e23f67a31e22587a7ef38166faff`.

## Gates ainda abertos

Assinatura, instalador, publicação pública, execução Windows nativa, WAN ENet independente, Steam de duas contas, Workshop real, editor gráfico exportado, gameplay manual revisado, aprovação audiovisual/pacing e promoção para `1.0` continuam pendentes. Consulte [`docs/pt-BR/CURRENT_STATUS.md`](docs/pt-BR/CURRENT_STATUS.md) e [`docs/pt-BR/KNOWN_LIMITS_MATRIX.md`](docs/pt-BR/KNOWN_LIMITS_MATRIX.md).
