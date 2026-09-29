# Testes do MODUS

> **Documentation status: maintained reference.** Este guia traduz inventário e execução. Resultados publicados e exclusões estão no [Estado Atual](CURRENT_STATUS.md); relatórios gerados são locais.

**Idiomas:** [English](../../tests/README.md) · [Português (Brasil)](TESTING.md)
**Atualizado:** 29 de setembro de 2026 · **Toolchain:** Godot 4.7.2 / GUT 9.7.1

## Limite atual

O agregado headless estrito de 29 de setembro passou 1.671/1.671 testes, 22.982 asserções em 149 scripts; dois arquivos GUI permanecem excluídos. O pipeline CI `36588760158` passou as lanes limitadas, contratos de release, exports, manifests, security scan e workflow de qualificação Windows.

Esses resultados são limitados ao escopo executado. Não substituem gameplay manual, performance sincronizada ao display, aceitação nativa, assinatura ou serviços externos.

Inventário mantido:

- 71 scripts unitários;
- 18 scripts de integração;
- 29 scripts de propriedade;
- 2 entradas GUI excluídas da seleção headless padrão;
- benchmark e ferramentas manuais fora da seleção GUT padrão.

## Comandos principais

```bash
# Seleção unit + integration + property
./tests/runners/run_all_tests_headless.sh

# Lanes duráveis e relatório local
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md

# Incluir arquivos GUI (ambiente gráfico pode ser necessário)
./tests/runners/run_all_tests_headless.sh --include-gui-required

# Smoke automatizado player-visible
tools/run_showcase_golden_demo_smoke.sh --strict

# Sessão humana normal com CSV
tools/run_manual_showcase_session.sh --tester NAME --input DEVICES

# Validators de evidência
tests/runners/test_manual_evidence_validator.sh
tests/runners/test_performance_evidence_validator.sh

# Contratos de release sem display/export
bash tests/runners/test_release_artifact_validator.sh
bash tests/runners/test_linux_portable_package.sh
bash tests/runners/test_release_staging.sh
bash tests/runners/test_overzeer_package.sh
bash tests/runners/test_overzeer_release_inventory.sh
bash tests/runners/test_deploy_overzeer_fleet.sh
bash tests/runners/test_prepare_ztash_release.sh
bash tests/runners/test_toolchain_lock.sh
```



## Ambiente

Defina `GODOT_BIN=/caminho/godot` quando necessário. Os runners isolam HOME, cache e configuração do Godot em `/tmp`, salvo overrides `MODUS_GODOT_*`. CI usa Godot 4.7.2 e GUT 9.7.1; `tools/toolchain.lock.json` verifica versões e hashes.

## Como interpretar

- PASS focado fecha somente o contrato indicado.
- Skip, pending, timeout ou resumo incompleto continuam sendo lacunas.
- Benchmark headless não é claim de renderer de produção.
- Manual, Steam, editor UI, hardware e peers externos precisam de evidência separada.
- Registre o comando, data, build, ambiente, resultado e exclusões no status/changelog.

## Verificação

```bash
bash tools/check_headless_runner_manifest.sh
bash tools/check_project_truth.sh
bash tools/check_documentation_truth.sh
```
