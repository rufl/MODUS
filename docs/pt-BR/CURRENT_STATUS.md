# Estado Atual do MODUS

> **Documentation status: maintained reference.** Este é o snapshot publicado e consolidado; relatórios e logs gerados são locais e cada resultado vale apenas para sua própria invocação.

**Idiomas:** [English](../CURRENT_STATUS.md) · [Português (Brasil)](CURRENT_STATUS.md)
**Atualizado:** 29 de setembro de 2026
**Versão:** `0.9.5-beta`
**Toolchain:** Godot 4.7.2 / GUT 9.7.1
**Prontidão:** **NÃO PRONTO**

## Resumo

MODUS possui uma base ampla de FPS, provas focadas de runtime e um smoke automatizado do Showcase. A evidência manual revisada ainda não existe e o gate de versão de release está bloqueado. O agregado headless estrito de 25 de setembro passou 1.665/1.665 testes, 22.767 asserções em 149 scripts; dois arquivos que exigem GUI permanecem excluídos.

O pipeline hospedado mais recente passou no commit `701ead4758c6e23f67a31e22587a7ef38166faff` (CI/CD `36588760158`, qualidade `36588760149`). Ele cobre formatação, lint, verdade do projeto, contratos de release, segurança, GUT, exports, manifests e o fluxo de qualificação do Windows. Isso não substitui execução manual ou hardware nativo aprovado.

## Dogfood autenticado

Pacotes ZTASH enxutos do payload GUI `6d0f781743e2dac90f0f33cd2f32c1f8c33b1f79` foram enviados por endpoints HTTPS separados e autenticados:

- DDJARIN / Windows: SHA-256 `45fa1f81a7c154ef971daf0557efe3128dab1ad11cd730e36a92507518d77363`.
- CHOPPER / Linux: SHA-256 `da865fa1a9f052eabcc8addf70402d660ddb984332a5c12a4f131b689b645667`.

O estado ativo dos receptores coincide com build, versão, target e tamanho registrados. Isto prova compatibilidade de pacote e transferência autenticada em dogfood. Os pacotes continuam sem assinatura; não há release público assinado, instalador ou aprovação nativa.

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
4. **Distribuição:** faltam certificado Authenticode, chave/política de assinatura, instalador, dependências nativas empacotadas e publicação pública.
5. **Produto:** faltam Workshop real, editor gráfico exportado, aprovação audiovisual/pacing e promoção de `0.9.5-beta` para release.

## Fontes canônicas

- [Contrato de verdade](../DOCUMENTATION_TRUTH.md)
- [Matriz de limites](../KNOWN_LIMITS_MATRIX.md)
- [Evidências de release](../RELEASE_EVIDENCE_BUNDLE.md)
- [Backlog ativo](../../BACKLOG.md)
- [Changelog](../../CHANGELOG.md)
