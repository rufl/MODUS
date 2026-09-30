# Estado Atual do MODUS

> **Documentation status: maintained reference.** Este é o snapshot publicado e consolidado; relatórios e logs gerados são locais e cada resultado vale apenas para sua própria invocação.

**Idiomas:** [English](../CURRENT_STATUS.md) · [Português (Brasil)](CURRENT_STATUS.md)
**Atualizado:** 30 de setembro de 2026
**Versão:** `0.9.5-beta`
**Toolchain:** Godot 4.7.2 / GUT 9.7.1
**Prontidão:** **NÃO PRONTO**

## Resumo

MODUS possui uma base ampla de FPS, provas focadas de runtime e um smoke automatizado do Showcase. A evidência manual revisada ainda não existe e o gate de versão de release está bloqueado. O agregado headless estrito de 29 de setembro passou 1.671/1.671 testes, 22.982 asserções em 149 scripts em 1.103,095 segundos; dois arquivos que exigem GUI permanecem excluídos.

O baseline atual de validação do código passou no commit `1367b270d651b1a2588044774a15f1dbeb2b8b51` (CI/CD `36779150278`, qualidade `36779150276`); commits somente de documentação também passam pelos mesmos workflows do GitHub Actions. Ele cobre formatação, lint, verdade do projeto, contratos de release, segurança, GUT, exports, manifests e o fluxo de qualificação do Windows. Isso não substitui execução manual ou hardware nativo aprovado.

## Dogfood autenticado

Pacotes ZTASH enxutos do build `1f6d4faf4a80f4426f85f3a6f731689d756806ef` foram enviados por endpoints HTTPS separados e autenticados:

- DDJARIN / Windows: SHA-256 `24a29d3eed0510d7993c99d9a97c7ff52358165485fac7f871b8874d50948d9b` / 141275566 bytes.
- CHOPPER / Linux: SHA-256 `63171873e1b7ed3cc7cd190694064e35724a03f75a38830fb121626907618f64` / 131419549 bytes.
- O manifesto ZTASH usa `size_bytes`, compatível com a ponte ZEER canônica; preview e deployment passaram.

O estado ativo dos receptores coincide com build, versão, target e tamanho registrados. Isto prova compatibilidade de pacote e transferência autenticada em dogfood. Os pacotes continuam sem assinatura. O [prerelease público `v0.9.5-beta`](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) é uma distribuição de clientes sem assinatura; não há release de produção assinado, instalador ou aprovação nativa.

## Prerelease público de 30 de setembro

O workflow `36779157160` publicou os clientes Linux, Windows e macOS a partir do build `1367b270d651b1a2588044774a15f1dbeb2b8b51`:

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `modus-0.9.5-beta-linux-x86_64.tar.gz` | 131401146 | `dc6fc0cb49aecdb8a075bdc45295a61b7622f340be3acb8d109608e074efb2b3` |
| `modus-0.9.5-beta-windows-x86_64.zip` | 141246788 | `77adbd95f005afdb0820215649b5b66b1d1c02c480a9b1b2d8c68cddfba1bd81` |
| `modus-0.9.5-beta-macos-universal.zip` | 152177480 | `0605a65ff3feff6a4705437d297c206162442788e564603ab1f85699691a0183` |

Os archives baixados passaram `SHA256SUMS` e integridade de compressão; o launcher Linux passou o smoke headless limitado. O executável Windows é PE32+ x86-64 e o macOS é Mach-O universal com duas arquiteturas. Os assets não têm assinatura; notarização macOS não está disponível. Isto prova distribuição beta pública, não aprovação de produção.

## O que está implementado e validado

- Manifests schema-v1 com paths relativos, identidade de commit/runtime, hashes SHA-256 e rejeição de conteúdo corrompido, ausente, duplicado ou escapando do root.
- Staging verificável antes/depois da cópia, recusa de destinos existentes, rollback de upgrade Linux, preservação de arquivos não pertencentes e dados XDG.
- OVERZEER em quatro formatos e ZTASH `ztash-release-v1`, com inventário e digest do `tools/toolchain.lock.json`.
- `--package-smoke` e `--capability-report` para validar recursos essenciais, identidade do runtime, classes nativas e dependências opcionais.
- Contrato de capacidades para CSG/MultiMesh/occlusion e diagnósticos explícitos para GodotSteam, `SteamMultiplayerPeer` e Voxel Tools, com fallback ENet/CSG quando permitido.
- ENet local em processos separados, reconnect, soak curto e host-loss controlado; contratos de autoridade, rate limits, save/load criptografado, mod SDK, editor e geração procedural em escopos focados.
- Breakwater com contrato de apresentação, estados de energia, áudio zonado, chuva, materiais de energia e asset dressing; prova autoral 12/12 com 144 asserções.

“Validado” sempre significa apenas o escopo indicado; não é aprovação de produto.

## Limitações abertas

1. **Manual:** o recorder existe, mas não há CSV revisado; horas validadas continuam em `0,00`.
2. **Windows nativo:** ainda falta executar o bundle em máquina Windows aprovada com renderer, W/Space/E físicos, workflow Showcase, save/load/mod e evidência de driver/janela.
3. **Rede externa:** faltam WAN ENet em redes independentes, reconnect/host-loss/soak de 10 minutos e Steam relay/P2P com duas contas quando aplicável.
4. **Distribuição:** faltam certificado Authenticode, chave/política de assinatura de produção, instalador, dependências nativas empacotadas e aprovação de release.
5. **Produto:** faltam Workshop real, editor gráfico exportado, aprovação audiovisual/pacing e promoção de `0.9.5-beta` para release.

## Fontes canônicas

- [Contrato de verdade](../DOCUMENTATION_TRUTH.md)
- [Matriz de limites](../KNOWN_LIMITS_MATRIX.md)
- [Evidências de release](../RELEASE_EVIDENCE_BUNDLE.md)
- [Backlog ativo](../../BACKLOG.md)
- [Changelog](../../CHANGELOG.md)
