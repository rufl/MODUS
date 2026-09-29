# Matriz de Limites Conhecidos do MODUS

> **Documentation status: maintained reference.** Esta matriz comunica limites de release. Ela não transforma resultado de código, teste automatizado, runtime, multiplayer, manual ou distribuição em prova mais ampla.

**Idiomas:** [English](../KNOWN_LIMITS_MATRIX.md) · [Português (Brasil)](KNOWN_LIMITS_MATRIX.md)
**Atualizado:** 29 de setembro de 2026
**Versão:** `0.9.5-beta` · **Prontidão:** **NÃO PRONTO**

Resultados abaixo são observações datadas. Logs e relatórios gerados são locais e não fazem parte de um clone limpo.

| Área | Limite verificado | Não verificado / limitação de release |
| --- | --- | --- |
| Testes automatizados | Agregado estrito de 25/09: 1.665/1.665 testes, 22.767 asserções, 149 scripts; dois arquivos GUI excluídos. CI `36588760158` passou no commit `701ead47`. | Testes GUI, sensação manual, performance sincronizada ao display e serviços externos continuam separados. |
| CI/CD | Formatação, lint, truth, contratos de release, segurança, GUT, exports, manifests e fluxo de qualificação Windows passaram. | CI hospedado não fecha aceitação nativa aprovada, WAN independente, Steam/Workshop, assinatura ou publicação. |
| Release engineering | OVERZEER completo em quatro formatos; ZTASH preparado; capability/package smoke, preview, deployment autenticado e reconciliação DDJARIN/CHOPPER passaram. | Inventário é `unsigned`; metadata do receptor é `signing: unavailable`; dogfood não é release assinado; não há instalador ou bundling nativo fechado. |
| Capacidades do runtime | `--capability-report` registra identidade, classes nativas e GodotSteam/SteamMultiplayerPeer/Voxel Tools; `--package-smoke` valida walk/CSG comum e falha fechado. | Não prova binários nativos empacotados, Windows nativo, Steam real, Workshop ou WAN. |
| Gameplay | Smoke Showcase passa cena, player, movimento, disparo, inimigo, pickup, save/load criptografado e mod de exemplo. | Não prova diversão, equilíbrio, recuperação de falha, sessão longa ou conclusão humana. |
| Evidência manual | Recorder F8/Gamepad Back, CSV, metadata e validador existem. | CSV revisado: 0; horas válidas: 0,00; nenhuma aprovação humana foi declarada. |
| Performance | Capture headless aquecida de 69,90 s / 66 amostras passa validação de forma. | Não é FPS alvo sincronizado ao display; mínimo observado 7,00 FPS exige revisão. Splitscreen, multiplayer, hardware baixo e sessão longa continuam abertos. |
| Multiplayer | ENet local em processos separados, reconnect/soak curto, host-loss controlado e contratos de autoridade focados passam. | WAN independente, host migration, soak real abusivo, lobby Steam com duas contas, relay/P2P e Workshop continuam abertos. |
| Editor | Round trip headless Linux editor → pacote → jogo preserva root, ownership, canais, geometria e `.mdsl`. | UI gráfica, input humano, Windows e Workshop real não estão aprovados. |
| Conteúdo audiovisual | Breakwater e Showcase têm contratos de apresentação, asset dressing e validação autoral focada. | Aprovação visual/auditiva, pacing de primeira jogada, conversão de normal maps e composição final permanecem abertas. |
| Distribuição | Proveniência atual do ledger está limpa e notices são verificados em escopos definidos. | Assinatura, instalador, dependências nativas, publicação pública, target Windows e versão 1.0 permanecem bloqueados. |

## Regra de aprovação

Não descreva MODUS como lançado, pronto para produção ou aprovado enquanto qualquer limitação necessária permanecer aberta. Veja o [estado atual](CURRENT_STATUS.md) e o [bundle de evidências](RELEASE_EVIDENCE_BUNDLE.md) para o escopo exato.
