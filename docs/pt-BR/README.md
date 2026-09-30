# Documentação MODUS — Português (Brasil)

> **Documentation status: maintained reference.** Esta área traduz as referências mantidas de maior uso. O inglês continua sendo a fonte canônica dos detalhes técnicos; os dois idiomas devem preservar o mesmo limite de evidência.

**Idiomas:** [English](../README.md) · [Português (Brasil)](README.md)
**Versão:** `0.9.5-beta` · **Toolchain:** Godot 4.7.2 · **Prontidão:** **BETA EXPERIMENTAL**

O baseline do beta público passou no commit `1367b270d651b1a2588044774a15f1dbeb2b8b51` (pipeline `36779150278`, qualidade `36779150276`). O [prerelease `v0.9.5-beta`](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) oferece arquivos Linux, Windows e macOS sem assinatura, acompanhados de checksums. Instaladores, aceitação nativa, gameplay manual revisado e provas externas Steam/WAN/Workshop continuam abertos.

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

Relatórios gerados e logs são saídas locais. Uma aprovação vale apenas para o comando, build, plataforma e escopo declarados. Smoke headless, simulação local ou CI não fecham gameplay manual, renderer nativo, Steam/WAN/Workshop, assinatura ou prontidão estável.
