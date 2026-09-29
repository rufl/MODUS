# Documentação MODUS — Português (Brasil)

> **Documentation status: maintained reference.** Esta área traduz as referências mantidas de maior uso. O inglês continua sendo a fonte canônica dos detalhes técnicos; os dois idiomas devem preservar o mesmo limite de evidência.

**Idiomas:** [English](../README.md) · [Português (Brasil)](README.md)
**Versão:** `0.9.5-beta` · **Toolchain:** Godot 4.7.2 · **Prontidão:** **NÃO PRONTO**

O pipeline hospedado `36588760158` passou no commit `701ead4758c6e23f67a31e22587a7ef38166faff`. O dogfood ZTASH autenticado está ativo no DDJARIN (Windows) e CHOPPER (Linux), mas os pacotes ainda não são assinados nem públicos.

## Verdade atual

1. [Contrato de verdade da documentação](DOCUMENTATION_TRUTH.md)
2. [Estado atual](CURRENT_STATUS.md)
3. [Matriz de limites conhecidos](KNOWN_LIMITS_MATRIX.md)
4. [Evidências de release](RELEASE_EVIDENCE_BUNDLE.md)
5. [Estimativa de prontidão](SHIP_READINESS_ESTIMATE.md)
6. [Backlog ativo](BACKLOG.md)
7. [Roadmap](ROADMAP.md)
8. [Plano de release e construção de mundo](RELEASE_AND_WORLD_BUILDING_PLAN.md)

## Guias traduzidos

- [Getting Started](GETTING_STARTED.md)
- [Requisitos de hardware e evidência](HARDWARE_REQUIREMENTS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Testes e runners](TESTING.md)

## Referências técnicas em inglês

As referências abaixo continuam mantidas em inglês para evitar duplicação de contratos de API. A navegação portuguesa aponta sempre para a mesma fonte publicada:

- [Arquitetura](../architecture.md)
- [Referência técnica](../TECHNICAL_REFERENCE.md)
- [Modelo de autoridade multiplayer](../MULTIPLAYER_AUTHORITY_MODEL.md)
- [Integração Steam](../technical/STEAM_INTEGRATION.md)
- [Modding](../guides/MODDING.md)
- [Console](../guides/CONSOLE.md)
- [Checklist de experiência do jogador](../../tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md)
- [Runners de teste](../../tests/runners/README.md)
- [Licenças e proveniência](../ATTRIBUTION.md)

## Regra de publicação

Relatórios gerados e logs são saídas locais. Uma aprovação vale apenas para o comando, build, plataforma e escopo declarados. Smoke headless, simulação local, CI ou dogfood autenticado não fecham manual gameplay, renderer nativo, Steam/WAN/Workshop, assinatura ou publicação pública.
