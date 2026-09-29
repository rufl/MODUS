# Bundle de Evidências de Release do MODUS

> **Documentation status: maintained reference.** Estes artefatos provam apenas o limite indicado; não são gameplay manual, performance de produção, multiplayer externo ou aprovação de release.

**Idiomas:** [English](../RELEASE_EVIDENCE_BUNDLE.md) · [Português (Brasil)](RELEASE_EVIDENCE_BUNDLE.md)
**Atualizado:** 29 de setembro de 2026
**Versão:** `0.9.5-beta` · **Prontidão:** **NÃO PRONTO**

## Estado atual de publicação

O pipeline de baseline de validação `36588760158` passou no commit `701ead4758c6e23f67a31e22587a7ef38166faff`; commits somente de documentação passam pelos mesmos workflows do GitHub Actions. Archives completos de cliente/servidor/editor passaram validação estrita de quatro formatos. Pacotes ZTASH enxutos passaram `--package-smoke`/`--capability-report` no Linux, capabilities autenticadas, preview e deployment dogfood.

Estado ativo reconciliado:

| Receptor | Target | SHA-256 | Limite |
| --- | --- | --- | --- |
| DDJARIN | Windows | `45fa1f81a7c154ef971daf0557efe3128dab1ad11cd730e36a92507518d77363` | Dogfood autenticado, não release assinado |
| CHOPPER | Linux | `da865fa1a9f052eabcc8addf70402d660ddb984332a5c12a4f131b689b645667` | Dogfood autenticado, não release assinado |

O payload comum é o build `6d0f781743e2dac90f0f33cd2f32c1f8c33b1f79`. Nenhuma chave de assinatura, certificado Authenticode, instalador ou publicação pública é reivindicada.

## Evidência automatizada mantida

- O golden demo automatizado registra cena, player, movimento, disparo, derrota de inimigo, pickup, save/load criptografado e carregamento do mod SDK de exemplo.
- O agregado headless estrito de 25 de setembro passa 1.665/1.665 testes com 22.767 asserções em 149 scripts; dois testes que exigem GUI permanecem excluídos.
- A captura Showcase aquecida de 69,90 segundos/66 amostras passa validação de forma. Ela não é benchmark sincronizado ao display.
- A suíte de release valida manifests, hashes, staging, inventários OVERZEER, ZTASH, notices, toolchain lock e lifecycle Linux em escopos focados.

## Evidência manual ausente

O recorder de 20 itens existe e gera CSV com metadata, Pass/Fail/Skip e tempo ativo. Nenhum CSV revisado foi importado; horas manuais validadas permanecem `0,00`. Capturas de UI automatizadas e vídeo do golden demo não contam como gameplay humano.

## Gates externos ainda abertos

- Renderer, janela, input físico W/Space/E, driver e workflow completo em Windows nativo.
- ENet WAN em redes independentes com latência/perda medidas, reconnect, host-loss e soak de 10 minutos.
- Steam relay/P2P com duas contas autorizadas, lobby, late join, reconnect e rejeições esperadas quando o perfil estiver habilitado.
- Workshop real com item app-owned, publicação, update, browse, subscribe, install, play e unsubscribe.
- Editor gráfico exportado, aprovação audiovisual/pacing e review manual do Breakwater.
- Assinatura, instalador, dependências nativas empacotadas e release pública.

## Regerar evidências

Consulte o [contrato de verdade em inglês](../DOCUMENTATION_TRUTH.md#regenerating-local-reports) para comandos, pré-requisitos, escopos e classificação de outputs locais. O [estado atual em português](CURRENT_STATUS.md) permanece a síntese operacional.
