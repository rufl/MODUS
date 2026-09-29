# Troubleshooting do MODUS

> **Documentation status: maintained reference.** Estes são checks do checkout atual. Relatórios históricos podem descrever caminhos, APIs ou falhas já corrigidos.

**Idiomas:** [English](../troubleshooting.md) · [Português (Brasil)](TROUBLESHOOTING.md)
**Atualizado:** 29 de setembro de 2026 · **Versão:** `0.9.5-beta`

## Comece pelo limite de evidência

Leia o [Estado Atual](CURRENT_STATUS.md) e a [Matriz de Limites](KNOWN_LIMITS_MATRIX.md). Relatórios gerados são locais; não transforme um smoke estreito em aprovação global.

## Godot não encontrado

Os runners procuram `GODOT_BIN`, depois `godot` e `godot4`:

```bash
GODOT_BIN=/caminho/absoluto/godot ./tests/runners/run_all_tests_headless.sh
```

Sem binário executável, o runner retorna 127.

## Erros de import ou cache

Os runners fazem import headless e isolam estado em `/tmp`. Feche o Godot antes de remover `.godot/`; cache gerado não é source e limpar cache não corrige código.

```bash
godot --headless --editor --path . --quit
```

## GUT sem resumo final

Log incompleto é BLOCKED, não PASS. Preserve o log e reproduza o menor arquivo:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_manager.gd
```

## Suite completa vermelha com foco verde

Verifique ownership/cleanup de fixtures, estado mutável entre iterações, subscriptions removidas, timers/threads encerrados, warnings intencionais consumidos e reset dos serviços. Um teste focado não substitui o agregado.

## Testes GUI excluídos

O runner padrão exclui os dois arquivos listados em `tests/runners/headless_gui_required_tests.txt`. `--include-gui-required` tenta incluí-los, mas input/renderização manual precisa de sessão gráfica isolada e evidência própria.

## ENet não abre socket

`tools/run_enet_local_smoke.sh` pode ser bloqueado por política de sockets do sandbox. Isso é um bloqueio de ambiente até reproduzir fora dele; não converta a falha em PASS de peer conectado.

## Steam indisponível

GodotSteam não vem no checkout. Fallback ENet e simulação local de Workshop não provam lobby, relay, autenticação, achievements ou upload/download real.

## Menu abre, gameplay não é provado

O smoke principal cobre startup. Use [Showcase Route](../SHOWCASE_ROUTE.md) e o [checklist manual em inglês](../../tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md); valide o CSV com:

```bash
tools/validate_manual_evidence.sh --strict
```

## Performance parece alta demais

A captura Showcase aquecida é headless/unthrottled, dura 69,90 s, tem 66 amostras e mínimo de 7,00 FPS. Ela prova formato/duração, não FPS sustentado em target.

## Editor standalone

O round trip headless Linux preserva root, ownership, canais, geometria, save/reopen/resave e `.mdsl`. Isso não prova UI gráfica polida, input humano, Windows ou Workshop.

## Servidor dedicado

Use a feature `dedicated_server`, `--dedicated-server`, `--modus-dedicated` ou `MODUS_DEDICATED_SERVER=1`. A configuração padrão é `user://server_config.json5`. Contratos locais ENet/Steam passam, mas WAN, duas contas Steam e deployment público não estão provados.

## Conflito documental

Use a precedência: source/configuração vivo → relatório mais recente realmente executado → docs mantidos → snapshots históricos. Execute `bash tools/check_documentation_truth.sh` depois de alterar docs.

## Relatar problema reproduzível

Registre binário/versão Godot, comando, exit code, resumo final, log, restrições do ambiente e se reproduz em foco. Evite “tudo falhou” sem lane e contagem.
