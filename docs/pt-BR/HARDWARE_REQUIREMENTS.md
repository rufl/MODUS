# Evidência e Requisitos de Hardware do MODUS

> **Documentation status: maintained reference.** Nenhum mínimo ou recomendado de shipping foi validado. Este documento registra apenas observações e requisitos ainda não provados.

**Idiomas:** [English](../hardware_requirements.md) · [Português (Brasil)](HARDWARE_REQUIREMENTS.md)
**Atualizado:** 29 de setembro de 2026 · **Versão:** `0.9.5-beta`

## O que pode ser afirmado

MODUS exige uma plataforma capaz de executar Godot 4.7 e a configuração de renderer/física do projeto. O repositório ainda não possui evidência para especificação mínima, recomendada ou ideal para clientes.

Não publique CPU, GPU, RAM, armazenamento, número de jogadores, resolução ou FPS derivados de tabelas antigas estimadas.

## Observação registrada

| Campo | Valor |
| --- | --- |
| Data | 27 de setembro de 2026 |
| GPU | Intel Arc A770 via Mesa |
| Renderer | Godot compatibility renderer |
| Cena | `res://game/world/maps/showcase.tscn` |
| Duração | 69,90 segundos |
| Amostras | 66 |
| Frame time máximo | 7,58 ms |
| FPS mínimo observado | 7,00 |

A captura foi headless/unthrottled e valida forma/duração da evidência, não target de hardware nem performance sincronizada ao display.

## Não provado

- Gameplay solo sincronizado ao display.
- Splitscreen com controles reais.
- Multiplayer com peers reais e WAN.
- Capacidade de servidor dedicado.
- GPUs integradas/low-end, Windows, macOS e Steam Deck.
- Estabilidade de memória em sessão longa.
- Combate pesado e editor/generator em carga real.
- Tamanho de download/instalação, bandwidth e latency requirements.

## Como produzir evidência válida

Registre commit/build, Godot, OS, renderer, driver, CPU/GPU/RAM, resolução, cena, modo, players, entidades, settings, duração, distribuição de FPS, memória, warnings, natureza headless/editor/export e CSV/log bruto. Depois execute:

```bash
tools/validate_performance_evidence.sh --strict
```

PASS do validator confirma somente forma e duração. Requirements de produto exigem sessões revisadas e repetíveis na matriz declarada.
