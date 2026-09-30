# Estimativa de Prontidão de Release do MODUS

> **Documentation status: maintained reference.** Este é um snapshot de completude de evidências, não aprovação de release. O status publicado está no [Estado Atual](CURRENT_STATUS.md).

**Idiomas:** [English](../SHIP_READINESS_ESTIMATE.md) · [Português (Brasil)](SHIP_READINESS_ESTIMATE.md)
**Estimativa:** 30 de setembro de 2026
**Target:** release distributivo com gates automatizados verdes, evidência revisada, artifacts assinados e claims públicos limitados.

## Gateboard atual

Não publicamos percentual ponderado: gates externos não são equivalentes a cobertura de código. Logs e relatórios gerados são locais.

| Gate | Estado | Evidência / pendência |
| --- | --- | --- |
| Verdade da documentação | **PASS** | Checks de documentação, projeto, runner-manifest e proveniência passam localmente |
| CI hospedado | **PASS** | Pipeline `36588760158` e qualidade `36588760149` passam no commit `701ead47` |
| Agregado Godot | **PASS / limitado** | 1.671/1.671 testes, 22.982 asserções, 149 scripts em 1.103,095 segundos; dois arquivos GUI excluídos |
| Release engineering | **PASS** | Validation, staging, lifecycle, ZTASH, fleet forwarding e toolchain lock focados passam |
| Dogfood autenticado | **PASS** | DDJARIN Windows (`24a29d3eed0510d7993c99d9a97c7ff52358165485fac7f871b8874d50948d9b`) e CHOPPER Linux (`63171873e1b7ed3cc7cd190694064e35724a03f75a38830fb121626907618f64`) reconciliam metadados imutáveis do build `1f6d4faf4a80f4426f85f3a6f731689d756806ef` |
| Gameplay manual | **BLOQUEADO / ferramenta pronta** | Recorder existe; CSV revisado `0`, horas validadas `0,00` |
| Performance | **LIMITADA** | Capture de 69,90 s/66 samples; não é target de FPS sincronizado ao display |
| Versão | **BLOQUEADO** | Projeto continua `0.9.5-beta`, não `1.0.0` |
| Assinatura/distribuição | **BLOQUEADO** | Prerelease público `v0.9.5-beta` existe sem assinatura; faltam assinatura de produção, notarização, instalador e certificado/chave |
| Runtime externo | **ABERTO** | Windows nativo, WAN, duas contas Steam, Workshop e editor gráfico não provados |
| Proveniência | **PASS / limitada** | Ledger atual limpo; notices e política distributiva continuam gates próprios |

## Caminho crítico

1. Coletar e revisar gameplay humano.
2. Executar o bundle de aceitação Windows em máquina aprovada.
3. Executar WAN ENet independente e Steam relay/P2P de duas contas quando aplicável.
4. Obter material de assinatura, definir instalador/política pública e publicar artifacts assinados.
5. Fechar runtime nativo, Workshop, editor gráfico e review audiovisual/pacing.
6. Promover a versão somente quando automação, manual, nativo, distribuição e direitos concordarem.

## Regra de aprovação

Não chame MODUS de lançado, pronto ou aprovado enquanto houver limitação necessária aberta. Dogfood autenticado sem assinatura prova transferência e compatibilidade, não aprovação de release.

## Verificação

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```
