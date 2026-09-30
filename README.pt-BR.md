# MODUS Framework

> **Documentation status: maintained reference.** Esta é a tradução brasileira da documentação publicada. A fonte de verdade sobre prontidão continua em [`docs/DOCUMENTATION_TRUTH.md`](docs/DOCUMENTATION_TRUTH.md) e [`docs/CURRENT_STATUS.md`](docs/CURRENT_STATUS.md).

**Idiomas:** [English](README.md) · [Português (Brasil)](README.pt-BR.md)

MODUS é um framework experimental de FPS multiplayer e um laboratório jogável de mecânicas para Godot 4.7. O projeto reúne combate, movimentação, armas, loot, IA inimiga, geração procedural, splitscreen, fundamentos multiplayer, editor de níveis e SDK de mods em uma base inspecionável.

**Versão:** `0.9.5-beta`
**Toolchain:** Godot 4.7.2 / GUT 9.7.1
**Prontidão:** **NÃO PRONTO**

## Estado atual

- O baseline de validação do código passou no commit `701ead4758c6e23f67a31e22587a7ef38166faff` (CI/CD `36588760158`; qualidade `36588760149`); commits somente de documentação também passam pelos mesmos workflows do GitHub Actions.
- A execução completa local de 29 de setembro passou 1.671/1.671 testes, com 22.982 asserções em 149 scripts; dois arquivos que exigem GUI continuam explicitamente excluídos.
- Pacotes ZTASH enxutos do build `1f6d4faf4a80f4426f85f3a6f731689d756806ef` foram validados e implantados por HTTPS autenticado para dogfood: DDJARIN mantém Windows (`24a29d3eed0510d7993c99d9a97c7ff52358165485fac7f871b8874d50948d9b`) e CHOPPER mantém Linux (`63171873e1b7ed3cc7cd190694064e35724a03f75a38830fb121626907618f64`).
- Esses pacotes são **não assinados** e não constituem lançamento público. Assinatura, instalador, aceitação nativa do Windows, evidência manual e provas externas de Steam/WAN/Workshop continuam abertas.

## Antes de clonar

MODUS é um projeto de desenvolvimento, não um jogo Steam pronto e não um template Godot de um clique. A primeira execução importa recursos e pode revelar diferenças de renderer, driver, plataforma ou integrações opcionais.

As integrações GodotSteam/Steam e Voxel Tools não são empacotadas por padrão. Os relatórios de capacidades detectam as classes e dependências presentes; caminhos incompatíveis são recusados ou explicitamente rebaixados para ENet/CSG quando permitido.

O Showcase é um smoke automatizado, não uma prova de que o jogo está divertido. As horas de gameplay manual revisadas continuam em `0,00`.

## Comece aqui

1. Instale Godot 4.7 na linha 4.7; CI usa 4.7.2.
2. Clone o repositório e execute `godot --editor --path .`.
3. Aguarde a importação inicial dos recursos.
4. Execute a cena principal `res://shared/ui_core/screens/main_menu_screen.tscn`.
5. Use `res://game/world/maps/showcase.tscn` para o percurso Showcase mantido.
6. Leia o [guia de início](docs/pt-BR/GETTING_STARTED.md), os [limites conhecidos](docs/pt-BR/KNOWN_LIMITS_MATRIX.md) e o [estado atual](docs/pt-BR/CURRENT_STATUS.md).

Verificação rápida sem abrir a interface:

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
```

## O que existe

- FPS solo, combate, armas, inimigos, loot, efeitos, missões e movimentação.
- ENet, validação autoritativa, whitelist/rate limits de RPC, servidor dedicado e estruturas condicionais de Steam.
- Splitscreen, editor embutido/standalone, serialização `.mdsl`, prefabs e simulação local de Workshop.
- Geração procedural com validação, navegação, exportação, perfis e testes focados.
- Descoberta de mods em pasta/PCK/ZIP, manifests, dependências, overrides, hooks e mod SDK de exemplo.

“Existe no código-fonte” não significa que o fluxo completo foi provado manualmente.

## Artefatos e dogfood

A engenharia de release produz manifests com identidade, hashes SHA-256, inventários OVERZEER de quatro formatos e pacotes ZTASH `ztash-release-v1`. O smoke `--package-smoke` verifica recursos essenciais; `--capability-report` registra identidade do runtime e dependências opcionais.

O batch de dogfood do commit GUI `6d0f781743e2dac90f0f33cd2f32c1f8c33b1f79` está reconciliado nos receptores:

- DDJARIN / Windows: `45fa1f81a7c154ef971daf0557efe3128dab1ad11cd730e36a92507518d77363`
- CHOPPER / Linux: `da865fa1a9f052eabcc8addf70402d660ddb984332a5c12a4f131b689b645667`

São hashes de validação de transferência autenticada, não assinaturas de release.

## O que ainda bloqueia a definição de pronto

1. Assinatura Linux/arquivos e Authenticode Windows, além de política e publicação pública.
2. Instalador e bundling de dependências nativas compatíveis, incluindo perfil GodotSteam/Voxel Tools quando suportado.
3. Aceitação nativa do Windows: renderer/janela/teclas físicas, fluxo Showcase completo, save/load criptografado, mod, ENet WAN, reconnect/host-loss/soak e Steam relay/P2P quando aplicável.
4. Gameplay manual revisado, avaliação audiovisual/pacing, editor gráfico exportado e Workshop real.
5. Promoção de `0.9.5-beta` para a versão de release somente quando todas as evidências atuais concordarem.

## Documentação

- [Índice português](docs/pt-BR/README.md)
- [Estado atual](docs/pt-BR/CURRENT_STATUS.md)
- [Matriz de limites](docs/pt-BR/KNOWN_LIMITS_MATRIX.md)
- [Evidências de release](docs/pt-BR/RELEASE_EVIDENCE_BUNDLE.md)
- [Roadmap](docs/pt-BR/ROADMAP.md)
- [Backlog](docs/pt-BR/BACKLOG.md)
- [Getting Started em inglês](docs/getting_started.md)
- [Testes em inglês](tests/README.md)
- [Licenças e proveniência](docs/ATTRIBUTION.md)

O projeto mantém licença MIT no código. Consulte a proveniência antes de redistribuir recursos ou dependências.
