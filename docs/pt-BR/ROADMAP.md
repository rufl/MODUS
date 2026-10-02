# Roadmap de Produto e Evidências do MODUS

> **Documentation status: maintained reference.** Este documento detalha o roadmap raiz por área. Implementação não é promovida automaticamente a prova de runtime ou release.

**Idiomas:** [English](../ROADMAP.md) · [Português (Brasil)](ROADMAP.md)
**Atualizado:** 30 de setembro de 2026
**Versão:** `0.9.5-beta` · **Prontidão:** **BETA EXPERIMENTAL**

## Limite de evidência atual

- Agregado headless estrito de 29/09: 1.671/1.671 testes, 22.982 asserções, 149 scripts; dois arquivos GUI excluídos.
- Pipeline `36779150278` e qualidade `36779150276` passaram no commit de release `1367b270d651b1a2588044774a15f1dbeb2b8b51`.
- O prerelease público `v0.9.5-beta` oferece arquivos Linux, Windows e macOS verificados por checksum; todos continuam sem assinatura.
- Gameplay manual: 0 arquivos importados / 0,00 horas.
- Performance: uma captura Showcase headless aquecida de 69,90 s / 66 amostras; alvos de produção ainda não provados.
- Release estável: bloqueado por assinatura, instaladores, aceitação nativa, multijogador representativo e serviços externos.

## Framework principal

| Área | Fonte | Prova necessária |
| --- | --- | --- |
| Serviços/GameManager | Implementados com cobertura focada | Estabilidade da suite agregada e ordem de lifecycle |
| Save/configuração | Contratos focados passam | Observação manual de save/load/corrupção |
| Eventos/componentes | Implementados e testados | Fluxos completos e evidência de usuário |

## Gameplay e Showcase

| Área | Fonte | Prova necessária |
| --- | --- | --- |
| Movimento/combate/armas | Golden demo automatizado passa dez etapas, incluindo a galeria de assets com texturas e 40 props importados sem colisão no mapa Showcase | Sensação humana, recuperação de falha e tuning |
| Showcase | Estrutura e welcome UI têm prova focada | Gameplay manual, vídeo revisado e issue log |
| IA/navegação | Vários contratos focados passam | Mapa real, stress e sessão longa |
| Splitscreen | Manager, gameplay e stress têm contratos | Controles reais, viewport, áudio e performance |

## Networking

| Área | Fonte | Prova necessária |
| --- | --- | --- |
| ENet local | Lifecycle, inventory, late join e host-loss controlado | Sessões revisadas, latência, reconnect e dedicated clients |
| Autoridade/segurança | Whitelist, validação e rate limits existem | Cliente adversarial e testes sob latência |
| Steam/GodotSteam | Contratos condicionais e inicialização local observada | Duas contas, Workshop, relay/P2P e serviço público |
| WAN | Harness suporta papéis Server/Client e probes | Hosts em redes independentes, perda, reconnect e soak |

## Editor, mods e Workshop

- Editor embutido/standalone preserva documento e exporta `.mdsl` headlessly; UI gráfica exportada ainda não está aceita.
- Mod loader/SDK e simulação local de Workshop passam contratos; publicação Steam real requer item app-owned e contas autorizadas.
- Undo/redo e authoring focados passam em escopo limitado; input e fluxo completo precisam de revisão humana.

## Geração e Breakwater

A revisão 2 do gerador isola RNG, valida topologia, baking de navegação e metadata. Planner/key-lock/placer/generator/export passa 49/49 testes com 697 asserções. Breakwater possui onze módulos, progressão de energia, áudio zonado, asset dressing e contrato de apresentação; aprovação visual, balanceamento, pacing e produção composta continuam abertos.

## Performance e distribuição

1. Capturar gameplay sincronizado ao display em solo, splitscreen e multiplayer.
2. Testar hardware mais fraco e uma sessão longa.
3. Revisar spikes, memória, teardown e anomalias, não apenas média de FPS.
4. Produzir packages suportados com runtime nativo, assinatura, notices e instalador.
5. Publicar apenas artifacts aprovados com manifests, hashes e evidências alvo.

## Critérios para candidato 1.0

- Suite agregada e lanes sem resultado incompleto oculto.
- Evidência manual revisada do percurso Showcase.
- Performance contextualizada para os modos/hardware declarados.
- Escopo multiplayer, package e runtime nativo provado.
- Windows nativo, Steam/Workshop/WAN e editor gráfico aceitos quando suportados.
- Proveniência, notices, assinatura e publicação aprovadas.
- Documentação sem afirmações mais fortes que a evidência.
