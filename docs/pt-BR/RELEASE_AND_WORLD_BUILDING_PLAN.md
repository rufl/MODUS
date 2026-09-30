# Plano de Release e Construção de Mundo do MODUS

> **Documentation status: maintained reference.** Pesquisa, decisões selecionadas e evidência de entrega ficam separadas. Correção do gerador e o gate de módulo/editor de três salas são exercitados; missão completa, aceitação gráfica e release continuam distintos.

**Idiomas:** [English](../RELEASE_AND_WORLD_BUILDING_PLAN.md) · [Português (Brasil)](RELEASE_AND_WORLD_BUILDING_PLAN.md)
**Atualizado:** 30 de setembro de 2026
**Versão:** `0.9.5-beta` · **Prontidão:** **BETA EXPERIMENTAL**

## Decisão de produto

Construir um sistema único de authoring com módulos autorais, mission graphs, montagem espacial limitada e resultados editáveis. Reutilizar generator, editor, mission service, save system e pacote `.mdsl`; não criar engine ou formato concorrente.

A meta é uma missão FPS compacta, polida, com combate legível, ritmo deliberado, traversal confiável e feedback audiovisual forte. Mais salas ou decoração aleatória não provam qualidade. Design de mundo e shipping são tracks separados: installer/release pode avançar sem Steam, e simulações locais não produzem prova WAN/Windows/Workshop.

## Estado implementado

- Breakwater Station: Black Start tem onze módulos detalhados, progressão por energia, maquinaria/luz, ambience zonada, suprimentos finitos e retorno ao hub.
- Generator revision 2 isola RNG, valida topologia, preserva records de key/lock/objective/recovery e assa navegação com collision real.
- MissionGraphPlanner publica profundidade de rota; encounter/resource pacing usa a topologia jogável.
- Editor e runtime compartilham metadata, canais, ownership de documento, pins, ghosts, partial regeneration e export `.mdsl`.
- Hub travel persistente restaura destino, actors, objetivos, loot e party com save criptografado; testes focados e cenário ENet de três processos passam.
- Contract de apresentação do Breakwater valida power stages, target groups, áudio zonado, chuva, relay labels e materiais; aprovação humana permanece aberta.
- O prerelease público `v0.9.5-beta` fornece arquivos Linux, Windows e macOS com checksums; assinatura, notarização, instaladores e aceitação nativa continuam abertos.

## Geração e authoring

A pipeline deve manter estes estágios: mission plan, progression validation, module selection, spatial solve, terrain/connectors, encounters/economy, presentation, bake/runtime validation e package. O manifest canônico deve carregar graph, módulos, transforms, connections, objectives, capabilities e content hashes. Saves e peers devem consumir esse resultado, não regenerar somente a partir de seed.

A montagem deve preservar sockets tipados, clearance, IDs estáveis, capacidades declaradas, navigation, spawn anchors e budgets. Falha de constraint deve nomear room/socket e publicar zero substituto parcial.

## Gates restantes

- Produzir e revisar o primeiro mission route em movimento: audiovisual, iluminação, áudio, pacing, balance e recovery.
- Fechar editor gráfico exportado: author, connect, play, save, reopen, package e game roundtrip em target aprovado.
- Empacotar runtime nativo compatível, notices e dependências; assinar e publicar artifacts.
- Executar Windows nativo, WAN ENet, Steam de duas contas e Workshop real.
- Importar gameplay manual revisado; o recorder não fabrica prova humana.

## Evidência

A implementação headless e os testes focados são contratos limitados. O [estado atual](CURRENT_STATUS.md), a [matriz de limites](KNOWN_LIMITS_MATRIX.md) e o [backlog raiz](../../BACKLOG.md) governam o que pode ser chamado de provado.
