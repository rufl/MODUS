# Estimativa de Prontidão de Release do MODUS

> **Documentation status: maintained reference.** Este é um snapshot de completude de evidências, não aprovação de release. O status publicado está no [Estado Atual](CURRENT_STATUS.md).

**Idiomas:** [English](../SHIP_READINESS_ESTIMATE.md) · [Português (Brasil)](SHIP_READINESS_ESTIMATE.md)
**Estimativa:** 30 de setembro de 2026
**Target:** release distributivo com gates automatizados verdes, evidência revisada, artifacts assinados e claims públicos limitados.

## Gateboard atual

Não publicamos percentual ponderado: gates externos não são equivalentes a cobertura de código. Logs e relatórios gerados são locais.

| Gate | Estado | Evidência / pendência |
| --- | --- | --- |
| Verdade da documentação | **PASS** | Checks de documentação, projeto, runner-manifest e proveniência passaram para o baseline do beta público |
| CI hospedado | **PASS** | Pipeline `36779150278` e qualidade `36779150276` passaram no commit de release `1367b270d651b1a2588044774a15f1dbeb2b8b51` |
| Agregado Godot | **PASS / limitado** | 1.671/1.671 testes, 22.982 asserções, 149 scripts em 1.103,095 segundos; dois arquivos GUI excluídos |
| Engenharia de release | **PASS** | Validação, staging, arquivos reprodutíveis, checksums, ciclo de pacote e toolchain lock passaram |
| Publicação beta | **PASS / sem assinatura** | Arquivos Linux x86-64, Windows x86-64 e macOS universal, mais `SHA256SUMS`, estão publicados como `v0.9.5-beta` |
| Gameplay manual | **BLOQUEADO / ferramenta pronta** | Recorder existe; CSV revisado `0`, horas validadas `0,00` |
| Performance | **LIMITADA** | Captura de 69,90 s/66 amostras; não é alvo sincronizado ao display; hardware de entrada e sessões longas estão abertos |
| Versão | **BETA** | Projeto continua `0.9.5-beta`, não `1.0.0` |
| Assinatura/instaladores | **BLOQUEADO** | Arquivos públicos não são assinados; macOS não é notarizado e não há instaladores polidos |
| Runtime externo | **ABERTO** | Aceitação nativa Windows/macOS, WAN representativa, duas contas Steam, Workshop e editor gráfico não foram provados |
| Proveniência | **PASS / limitada** | Ledger atual limpo; notices e política distributiva continuam gates próprios |

## Caminho crítico

1. Coletar e revisar gameplay humano.
2. Executar aceitação nativa Windows e macOS em sistemas representativos.
3. Executar WAN ENet representativa e Steam relay/P2P com duas contas quando aplicável.
4. Obter material de assinatura, definir política de instaladores e publicar artefatos assinados.
5. Fechar runtime nativo, Workshop, editor gráfico e review audiovisual/pacing.
6. Promover a versão somente quando automação, manual, nativo, distribuição e direitos concordarem.

## Regra de aprovação

Não chame MODUS de estável, pronto para produção ou aprovado enquanto houver limitação necessária aberta. O beta público prova um caminho limitado de build e publicação, não aprovação estável.

## Verificação

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```
