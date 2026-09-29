# Começando com MODUS

> **Documentation status: maintained reference.** MODUS está em `0.9.5-beta` e NÃO está pronto para produção. Este guia executa o checkout atual; não é promessa de release.

**Idiomas:** [English](../getting_started.md) · [Português (Brasil)](GETTING_STARTED.md)
**Atualizado:** 29 de setembro de 2026 · **Toolchain:** Godot 4.7.2 / GUT 9.7.1

## Requisitos

- Godot 4.7 na linha 4.7; CI usa 4.7.2.
- Bash e Python 3.10+ para verificações e helpers de release.
- `zstd` para operações `.tar.zst`.
- `/tmp` gravável para os runners headless isolados.
- Sessão gráfica para editor, input e evidência manual.
- GodotSteam não é incluído; Steam exige extensão, App ID, contas autorizadas e validação separada.

## Abrir e executar

Na raiz do repositório:

```bash
godot --editor --path .
```

A cena principal é `shared/ui_core/screens/main_menu_screen.tscn`. Smoke de inicialização:

```bash
tools/run_main_player_path_smoke.sh --strict
```

Esse smoke prova apenas inicialização/menu. Não prova movimento, combate, save, multiplayer ou editor.

## Exportar Linux localmente

Instale o template de exportação Linux do Godot 4.7:

```bash
mkdir -p standalone/client
godot --headless --path . --export-release "Linux Desktop" standalone/client/modus.x86_64
tools/run_export_smoke.sh --platform linux --executable standalone/client/modus.x86_64
```

O smoke prova um launch Linux limitado. Não prova instalador, assinatura, Steam, Windows nativo, gameplay manual ou sessão longa.

## Empacotar cliente Linux local

Depois de produzir o executável e `.pck` adjacente:

```bash
tools/package_linux_portable.sh package \
  --artifact-dir standalone/client \
  --output /tmp/modus-linux-0.9.5-beta.tar.zst
tools/package_linux_portable.sh install \
  --archive /tmp/modus-linux-0.9.5-beta.tar.zst \
  --prefix "$HOME/.local/opt/modus"
tools/package_linux_portable.sh verify --prefix "$HOME/.local/opt/modus"
tools/package_linux_portable.sh uninstall --prefix "$HOME/.local/opt/modus"
```

`.tar.zst` é preferido para transferência; `.tar.gz` também é aceito. O helper valida o arquivo, faz rollback de falhas, preserva arquivos não pertencentes e mantém saves/config XDG. É um pacote portátil local não assinado, não um instalador ou release público.

## Verificar o checkout

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
```

Testes automatizados:

```bash
./tests/runners/run_all_tests_headless.sh
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
```

Relatórios e logs são saídas locais ignoradas. Consulte o [contrato de verdade](DOCUMENTATION_TRUTH.md#regerar-relatórios) e o [estado atual](CURRENT_STATUS.md); uma verificação de fonte limpa não significa que a suite de jogo passou.

## Primeiro ajuste seguro

1. Encontre o arquivo fonte e o teste focado correspondente.
2. Faça a menor mudança coerente.
3. Execute formatter/lint dos scripts tocados.
4. Execute o teste focado e a lane relevante.
5. Atualize backlog, changelog e status com o limite exato da evidência.
6. Não declare prova manual, hardware, Steam ou peers conectados sem observação real.

## Próximas referências

- [Estado atual](CURRENT_STATUS.md)
- [Arquitetura em inglês](../architecture.md)
- [Testes](TESTING.md)
- [Modding em inglês](../guides/MODDING.md)
- [Troubleshooting](TROUBLESHOOTING.md)
