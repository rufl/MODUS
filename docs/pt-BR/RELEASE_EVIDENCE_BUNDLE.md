# Bundle de Evidências de Release do MODUS

> **Documentation status: maintained reference.** Estes artefatos provam apenas o limite indicado; não são gameplay manual, performance de produção, multiplayer externo ou aprovação de release.

**Idiomas:** [English](../RELEASE_EVIDENCE_BUNDLE.md) · [Português (Brasil)](RELEASE_EVIDENCE_BUNDLE.md)
**Atualizado:** 30 de setembro de 2026
**Versão:** `0.9.5-beta` · **Prontidão:** **NÃO PRONTO**

## Estado atual de publicação

O pipeline de baseline de validação `36779150278` passou no commit `1367b270d651b1a2588044774a15f1dbeb2b8b51`; commits somente de documentação passam pelos mesmos workflows do GitHub Actions. Archives completos de cliente/servidor/editor passaram validação estrita de quatro formatos. Pacotes ZTASH enxutos do build `1f6d4faf4a80f4426f85f3a6f731689d756806ef` passaram `--package-smoke`/`--capability-report`, preview ZEER e deployment dogfood autenticado. O prerelease público abaixo é uma distribuição separada de clientes sem assinatura; gates de produção continuam abertos.

Estado ativo reconciliado:

| Receptor | Target | SHA-256 | Limite |
| --- | --- | --- | --- |
| DDJARIN | Windows | `24a29d3eed0510d7993c99d9a97c7ff52358165485fac7f871b8874d50948d9b` | Dogfood autenticado, não release assinado |
| CHOPPER | Linux | `63171873e1b7ed3cc7cd190694064e35724a03f75a38830fb121626907618f64` | Dogfood autenticado, não release assinado |

O payload de dogfood é o build `1f6d4faf4a80f4426f85f3a6f731689d756806ef`. Nenhuma chave de assinatura, certificado Authenticode ou instalador é reivindicado para esses pacotes; o prerelease público GitHub é documentado separadamente abaixo.

## Artifact beta público do GitHub

O [`v0.9.5-beta`](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) foi publicado pelo workflow `36779157160` a partir do build `1367b270d651b1a2588044774a15f1dbeb2b8b51`.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `modus-0.9.5-beta-linux-x86_64.tar.gz` | 131401146 | `dc6fc0cb49aecdb8a075bdc45295a61b7622f340be3acb8d109608e074efb2b3` |
| `modus-0.9.5-beta-windows-x86_64.zip` | 141246788 | `77adbd95f005afdb0820215649b5b66b1d1c02c480a9b1b2d8c68cddfba1bd81` |
| `modus-0.9.5-beta-macos-universal.zip` | 152177480 | `0605a65ff3feff6a4705437d297c206162442788e564603ab1f85699691a0183` |
| `SHA256SUMS` | 308 | `42346a904f4114d769c5ada42595ca9454590018fd25a558da11a05678b63d48` |

Os downloads passaram `SHA256SUMS`, integridade `tar`/`unzip`, smoke headless Linux, identificação PE32+ x86-64 no Windows e identificação Mach-O universal de duas arquiteturas no macOS. Os archives não têm assinatura e a notarização macOS está indisponível. Isto prova distribuição beta e integridade, não aprovação de release.

## Evidência automatizada mantida

- O golden demo automatizado registra cena, player, movimento, disparo, derrota de inimigo, pickup, save/load criptografado e carregamento do mod SDK de exemplo.
- O agregado headless estrito de 29 de setembro passa 1.671/1.671 testes com 22.982 asserções em 149 scripts; dois testes que exigem GUI permanecem excluídos.
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
- Assinatura de produção, instalador, dependências nativas empacotadas e release assinado/notarizado continuam abertos; o prerelease beta público não fecha esses gates.

## Regerar evidências

Consulte o [contrato de verdade em inglês](../DOCUMENTATION_TRUTH.md#regenerating-local-reports) para comandos, pré-requisitos, escopos e classificação de outputs locais. O [estado atual em português](CURRENT_STATUS.md) permanece a síntese operacional.
