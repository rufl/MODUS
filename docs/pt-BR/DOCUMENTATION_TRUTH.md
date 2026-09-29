# Contrato de Verdade da Documentação MODUS

> **Documentation status: maintained reference.** Este documento define a política de publicação. Resumos commitados registram observações datadas e limitadas; relatórios gerados descrevem apenas a invocação local.

**Idiomas:** [English](../DOCUMENTATION_TRUTH.md) · [Português (Brasil)](DOCUMENTATION_TRUTH.md)
**Atualizado:** 29 de setembro de 2026
**Versão:** `0.9.5-beta`
**Toolchain:** Godot 4.7.2 / GUT 9.7.1
**Prontidão:** **NÃO PRONTO**

## Fontes canônicas

Quando documentos divergirem, use:

1. [Estado Atual](CURRENT_STATUS.md) para implementação e evidência datada.
2. [Matriz de Limites](KNOWN_LIMITS_MATRIX.md) para exclusões e provas pendentes.
3. [Backlog](BACKLOG.md) e [Roadmap](ROADMAP.md) para trabalho aberto e contratos de aceitação.
4. [Changelog raiz](../../CHANGELOG.md) para trabalho concluído e seu escopo.
5. [Bundle de Evidências](RELEASE_EVIDENCE_BUNDLE.md) para capturas, proveniência, hashes e exclusões de release.

O baseline atual de validação do código passou no commit `701ead4758c6e23f67a31e22587a7ef38166faff` (pipeline `36588760158`). Commits somente de documentação também passam pelos mesmos workflows do GitHub Actions. O agregado headless estrito de 25 de setembro continua sendo a última evidência publicada de suite completa: 1.665/1.665 testes, 22.767 asserções em 149 scripts, com dois arquivos GUI excluídos. O dogfood ZTASH autenticado passou, mas os pacotes permanecem sem assinatura e os gates público, nativo e externo continuam abertos.

## Retenção local

O GitHub publica código, testes, CI, licenças, mídia curada, documentação mantida e guias. `logs/`, caches, memória de agentes, auditorias históricas, sessões antigas e relatórios gerados são locais ou ausentes de clones novos. Não force a publicação de um arquivo histórico para restaurar um link.

Um PASS histórico nunca deve ser apresentado como uma nova execução. Publique somente a conclusão curta, a data, o build, o comando e as exclusões relevantes.

## Regerar relatórios

Execute na raiz, com dependências instaladas:

| Saída local | Comando | Limite |
| --- | --- | --- |
| Lanes automatizadas | `./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md` | Apenas lanes executadas; skip/incompleto continua explícito |
| Smoke principal | `tools/run_main_player_path_smoke.sh --strict` | Apenas inicialização do menu |
| Smoke Showcase | `tools/run_main_player_path_smoke.sh --target world --report docs/SHOWCASE_LAUNCH_SMOKE.md --strict` | Apenas carregamento do mundo |
| Golden demo | `tools/run_showcase_golden_demo_smoke.sh --strict` | Gameplay automatizado controlado, não sensação humana |
| Evidência manual | `tools/validate_manual_evidence.sh --strict` | Exige CSV ManualTestTimer revisado |
| Evidência de performance | `tools/validate_performance_evidence.sh --strict` | Forma/duração de CSV contextualizado |
| Readiness de release | `tools/validate_release_readiness.sh --strict` | Gate de versão, não aprovação |
| Readiness de produção | `tools/validate_production_readiness.sh --run-godot-tests --strict` | Agregado local, não liberação legal/distributiva |

O runner completo é `./tests/runners/run_all_tests_headless.sh`. Capture evidência manual com `tools/run_manual_showcase_session.sh --tester NAME --input DEVICES`. Uma regeneração cria uma observação nova; não recria hardware, bytes ou resultado de uma execução antiga.

## Regras de afirmação

- “Implementado” significa que existe um caminho de código vivo; não significa prova de UX ou runtime.
- “Testado” deve nomear comando, data, resultado e exclusões.
- “Runtime” deve identificar cena/caminho e comportamento observado.
- “Manual” exige observação humana revisada e evidência registrada.
- “Performance” deve informar hardware, renderer, duração e exclusões.
- “Steam” exige cliente rodando, App ID, autorização e resultado real da API.
- “Pronto”, “lançado” e “completo” não podem ser usados como estado presente do projeto enquanto gates necessários estiverem bloqueados.

## Verificação

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
```
