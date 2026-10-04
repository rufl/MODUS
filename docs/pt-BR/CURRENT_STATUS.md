# Status Atual do MODUS

> **Documentation status: maintained reference.** Atualizado em 2026-09-30. Este documento separa disponibilidade no código, observações focadas e prontidão de entrega. Uma verificação aprovada prova apenas a fronteira exercitada.

## Baseline

| Item | Valor |
| --- | --- |
| Versão | `0.9.5-beta` |
| Engine | Godot `4.7.2` (feature de projeto `4.7+`) |
| Versão pública | [`v0.9.5-beta`](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) |
| Commit da versão | `1367b270d651b1a2588044774a15f1dbeb2b8b51` |
| Licença | MIT para o código; assets de terceiros mantêm seus próprios termos |
| Prontidão | Beta experimental; não pronto para produção |

## Vocabulário

- **Implementado:** código e dados existem na árvore atual.
- **Observado:** uma verificação focada ou rota manual exercitou a fronteira indicada.
- **Aberto:** ainda falta aceitação representativa, segurança, escala, plataforma ou usabilidade.

Implementado não significa observado. Observado não significa pronto para produção.

## Matriz de capacidades

| Capacidade | Implementado | Fronteira observada | Trabalho aberto importante |
| --- | --- | --- | --- |
| Movimento e combate | Estados de movimento, armas, dano, projéteis, efeitos e física | Testes focados e rota automatizada de demonstração | Balanceamento, hardware variado e sessões longas |
| Inventário e loot | Registros, coletas, drops, operações de inventário e tabelas | Testes determinísticos e caminhos autorais | Progressão e economia mais amplas |
| Inimigos e partidas | Comportamentos, estado de partida, pontuação, cronômetros e encontros | Testes focados e smoke dos mundos de demonstração | Variedade representativa e sessões extensas |
| Mundos procedurais | Geração com semente, workers, contratos de layout e integração autoral | Determinismo e geração limitada | Soak de mundos grandes, pressão de memória e mais sementes |
| Multijogador ENet | Hospedagem/entrada, servidor dedicado, autoridade, allowlist de RPC, limites, predição e reconexão | Ciclo local, inventário, reconexão, late join e autoridade | Internet real, latência/perda, clientes hostis, concorrência e aceitação dedicada |
| Steam | Adapter e inicialização condicional | Inicialização local autenticada | Duas contas, relay/P2P, serviços públicos e Workshop |
| Editor | Editor embutido, código standalone, exportação/importação `.mdsl` e histórico | Save/export/reload e histórico focados | Fluxo gráfico completo do aplicativo exportado |
| Mods | JSON/JSON5, registros, exemplos, sobrescritas e validação de pacotes | Sistema de arquivos local, checagens de compatibilidade de mods/saves e mod de exemplo | Distribuição pública, migração de schema e garantias de sandbox |
| UI e entrada | Menu, opções, gerenciador de mods, navegação por gamepad e showcase | Capturas smoke em 800×600 e 1280×720 | Localização, acessibilidade, proporções incomuns e matriz de controles |
| Desempenho | Benchmarks, orçamentos, telemetria e validadores | Medidas locais limitadas | Hardware de entrada, escala multijogador e sessões longas |

## Evidência do beta público

O workflow público produziu arquivos Linux x86-64, Windows x86-64 e macOS universal, além de um manifesto de checksums. A integridade dos arquivos e um startup headless limitado no Linux foram verificados antes da publicação.

| Asset | SHA-256 |
| --- | --- |
| `modus-0.9.5-beta-linux-x86_64.tar.gz` | `dc6fc0cb49aecdb8a075bdc45295a61b7622f340be3acb8d109608e074efb2b3` |
| `modus-0.9.5-beta-windows-x86_64.zip` | `77adbd95f005afdb0820215649b5b66b1d1c02c480a9b1b2d8c68cddfba1bd81` |
| `modus-0.9.5-beta-macos-universal.zip` | `0605a65ff3feff6a4705437d297c206162442788e564603ab1f85699691a0183` |
| `SHA256SUMS` | `42346a904f4114d769c5ada42595ca9454590018fd25a558da11a05678b63d48` |

O pacote Windows contém um executável PE x86-64. O aplicativo macOS contém slices Mach-O x86-64 e arm64. Verificação de formato não substitui aceitação nativa.

## Bloqueios para uma entrega estável

1. assinatura e notarização para as plataformas suportadas;
2. aceitação nativa Windows e macOS em sistemas representativos;
3. testes de rede com latência, perda, escala e comportamento adversarial;
4. aceitação completa do editor e do fluxo de mods exportados;
5. validação mais ampla de acessibilidade, controles e localização;
6. evidência em hardware de entrada e sessões longas;

## Política de compatibilidade

A política de compatibilidade de mods e saves está documentada e aplicada pelo validador e pelo runtime local. Distribuição pública, migração de schema, aceitação nativa e garantias de sandbox continuam fora dessa evidência.

## Referências
- [Política de Compatibilidade de Mods e Saves](../MOD_COMPATIBILITY_POLICY.md)

- [Pacote de Evidências](./RELEASE_EVIDENCE_BUNDLE.md)
- [Matriz de Limites](../KNOWN_LIMITS_MATRIX.md)
- [Modelo de Autoridade](../MULTIPLAYER_AUTHORITY_MODEL.md)
- [Prova de Performance](../PERFORMANCE_BASELINE_PROOF.md)
- [Prova de Round Trip do Editor](../EDITOR_ROUNDTRIP_PROOF.md)
- [Verdade da Documentação](./DOCUMENTATION_TRUTH.md)
- [Roadmap](../ROADMAP.md)

## Atualização do baseline

```bash
bash tools/check_project_truth.sh
bash tools/check_documentation_truth.sh
bash tools/check_headless_runner_manifest.sh
```

Verificações gráficas devem usar um ambiente de display isolado e descartável. Matrizes completas ficam reservadas para verificação final explícita; resultados históricos não certificam commits posteriores.
