# Backlog MODUS — Português (Brasil)

> **Documentation status: maintained reference.** Este resumo traduz o backlog ativo; o backlog raiz em inglês permanece a lista operacional completa.

**Idiomas:** [English](../../BACKLOG.md) · [Português (Brasil)](BACKLOG.md)
**Atualizado:** 30 de setembro de 2026 · **Versão:** `0.9.5-beta` · **Prontidão:** **NÃO PRONTO**

## Snapshot atual

- Baseline de validação do código: CI/CD `36779150278` e qualidade `36779150276` passaram no commit `1367b270d651b1a2588044774a15f1dbeb2b8b51`; commits somente de documentação passam pelos mesmos workflows do GitHub Actions.
- Archives OVERZEER completos passaram validação estrita de quatro formatos.
- ZTASH enxuto passou package smoke/capability report e foi implantado por HTTPS autenticado para dogfood.
- DDJARIN reconcilia Windows `45fa1f81a7c154ef971daf0557efe3128dab1ad11cd730e36a92507518d77363`.
- CHOPPER reconcilia Linux `da865fa1a9f052eabcc8addf70402d660ddb984332a5c12a4f131b689b645667`.
- Os artifacts de dogfood continuam sem assinatura. O [prerelease público `v0.9.5-beta`](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) publica clients Linux, Windows e macOS sem assinatura; isso não é publicação de produção.

- O workflow beta `36779157160` publicou e verificou os archives públicos; assinatura de produção, notarização, instalador e gates nativos/manuais/externos permanecem abertos.

## Tags de prova

- `[truth:source-audit]` — inspeção de fonte, referência ou artifact.
- `[truth:docs]` — mudança documental verificada por truth check/scan.
- `[truth:test]` — teste ou smoke automatizado executado.
- `[truth:runtime]` — comportamento de jogo/editor lançado e observado.
- `[truth:manual]` — teste humano executado e registrado.
- `[truth:blocked]` — bloqueio por binário, serviço, dependência, asset ou condição externa.
- `[truth:deferred]` — trabalho adiado com motivo e condição de retorno.

## Aceitação nativa Windows

Um único build exportado imutável em uma máquina Windows aprovada pode fechar esta linha, desde que o bundle retenha commit, manifests, hashes, preset, versões, GPU/driver/renderer, logs e captura de janela nativa.

1. **Renderer/input:** janela não-headless, renderer/GPU/viewport declarados, W/Space/E físicos, resultados de movimento/pulo/interação e saída limpa.
2. **Conteúdo/save:** Showcase, player, movimento, arma contra inimigo vivo, derrota, pickup, save/load criptografado e mod SDK; remover slots e staging ao final.
3. **Rede:** ENet local multiprocess, WAN direto em redes independentes e Steam relay/P2P com duas contas se habilitado; provar entrega, reconnect, host-loss, latência/perda e soak.

Loopback, Linux, Wine, editor, input sintético, uma conta Steam ou simulação local não fecham estes gates.

## Pendências prioritárias

- Importar CSV manual revisado e limpar o bloqueio de `0,00` horas.
- Obter certificado Authenticode/chaves e implementar fluxo de assinatura verificável.
- Definir instalador, runtime nativo empacotado e publicação pública de produção assinada.
- Executar Windows nativo, WAN, Steam de duas contas e Workshop real.
- Fechar editor gráfico exportado, review audiovisual/pacing e primeiro mission composed de Breakwater.
- Promover `0.9.5-beta` somente após todos os gates atuais concordarem.

## Limites

Código implementado, teste focado, CI, package smoke, dogfood autenticado e prerelease beta público não equivalem a aprovação manual, target-native, Steam/WAN/Workshop, assinatura ou release de produção.
