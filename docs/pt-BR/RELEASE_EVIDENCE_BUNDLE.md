# Pacote de Evidências da Versão MODUS

> **Documentation status: maintained reference.** Atualizado em 2026-09-30. Este pacote torna a evidência do beta público fácil de inspecionar sem transformar verificações limitadas em promessas amplas.

## Identidade da versão

| Campo | Valor |
| --- | --- |
| Tag | [`v0.9.5-beta`](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) |
| Commit | `1367b270d651b1a2588044774a15f1dbeb2b8b51` |
| Engine | Godot `4.7.2-stable` |
| Licença | MIT para o código; veja [Atribuição](../ATTRIBUTION.md) para termos de terceiros |
| Distribuição | Arquivos beta sem assinatura; macOS sem notarização |

## Artefatos publicados

| Artefato | Tamanho (bytes) | SHA-256 |
| --- | ---: | --- |
| `modus-0.9.5-beta-linux-x86_64.tar.gz` | 131.401.146 | `dc6fc0cb49aecdb8a075bdc45295a61b7622f340be3acb8d109608e074efb2b3` |
| `modus-0.9.5-beta-windows-x86_64.zip` | 141.246.788 | `77adbd95f005afdb0820215649b5b66b1d1c02c480a9b1b2d8c68cddfba1bd81` |
| `modus-0.9.5-beta-macos-universal.zip` | 152.177.480 | `0605a65ff3feff6a4705437d297c206162442788e564603ab1f85699691a0183` |
| `SHA256SUMS` | — | `42346a904f4114d769c5ada42595ca9454590018fd25a558da11a05678b63d48` |

```bash
sha256sum --check SHA256SUMS
```

No Windows, use `Get-FileHash`; no macOS, `shasum -a 256`.

## O que o workflow estabeleceu

- Exports Linux, Windows e macOS foram concluídos a partir da fonte marcada.
- Os arquivos abriram e corresponderam à estrutura esperada.
- O binário Linux completou um startup headless limitado.
- O cliente Windows foi identificado como PE32+ x86-64.
- O aplicativo macOS contém slices Mach-O x86-64 e arm64.
- Os checksums foram calculados sobre os arquivos finais enviados.

## O que não foi estabelecido

- assinatura, notarização ou reputação com sistemas de segurança das plataformas;
- aceitação nativa de gameplay no Windows ou macOS;
- qualidade gráfica em diferentes drivers, telas e configurações de acessibilidade;
- multijogador em serviços públicos, Steam ou Workshop;
- certificação de segurança, desempenho ou prontidão para produção.

## Evidência visual curada

| Superfície | 1280×720 | 800×600 | Objetivo |
| --- | --- | --- | --- |
| Menu principal | [PNG](../media/release/main_menu_1280x720.png) | [PNG](../media/release/main_menu_800x600.png) | Navegação principal sobre o horizonte procedural |
| Boas-vindas do showcase | [PNG](../media/release/showcase_welcome_1280x720.png) | [PNG](../media/release/showcase_welcome_800x600.png) | Rota guiada de evidência |
| Gerenciador de mods | [PNG](../media/release/mod_manager_1280x720.png) | [PNG](../media/release/mod_manager_800x600.png) | Descoberta e gestão de mods |
| Gravador de evidência | [PNG](../media/release/manual_evidence_recorder_1280x720.png) | [PNG](../media/release/manual_evidence_recorder_800x600.png) | Contrato de observação manual |

A [captura automatizada mais recente do showcase](../media/release/golden_demo_smoke_1280x720.mp4) prova apenas que a rota roteirizada foi concluída.

## Reprodução

```bash
bash tools/check_project_truth.sh
bash tools/check_documentation_truth.sh
bash tests/runners/test_release_archive_package.sh
```

O workflow está em [`.github/workflows/beta-release.yml`](../../.github/workflows/beta-release.yml), e a construção dos arquivos está em [`tools/package_release_archive.py`](../../tools/package_release_archive.py). Verificações gráficas exigem um display isolado e descartável.

Para a fronteira completa, leia [Status Atual](./CURRENT_STATUS.md) e a [Matriz de Limites](../KNOWN_LIMITS_MATRIX.md).
