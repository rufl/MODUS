# Registro de Alterações

> **Documentation status: maintained reference.** Histórico público de versões e mudanças ainda não publicadas.

As mudanças públicas importantes do MODUS são registradas aqui. O projeto segue as convenções do [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) enquanto permanece pré-1.0.

## [Não publicado]

### Adicionado

- Página inicial renovada com downloads, arquitetura, fronteiras de evidência e caminhos de contribuição.
- Formulários de issue, checklist de pull request, Código de Conduta, guia de contribuição, canal privado de segurança, regras de ownership e atualização automática de GitHub Actions.
- Configuração de varredura de segredos com exclusões documentadas para falsos positivos.

### Alterado

- Ferramentas de empacotamento e limpeza agora usam conceitos públicos do MODUS.
- Documentação de entrega reduzida a evidência atual, checksums, limitações e comandos reproduzíveis.
- Telemetria local de validação descrita como opt-in e sem dependência de serviço remoto.
- A arte de guerreiro do menu principal foi substituída pelo horizonte procedural no jogo e nas capturas públicas.
- O vídeo público automatizado do showcase foi atualizado a partir da rota mantida mais recente.

### Removido

- Referências de implantação privada, estações de trabalho e integrações não publicadas da árvore pública.
- O asset-fonte de guerreiro não utilizado e sua entrada de proveniência foram removidos.

## [0.9.5-beta] - 2026-09-30

### Adicionado

- Arquivos beta públicos para Linux x86-64, Windows x86-64 e macOS universal.
- Manifesto SHA-256 para todos os downloads de gameplay.
- Verificação automática de integridade, formato, arquitetura e startup headless limitado no Linux.
- Mídia curada do menu, showcase, gerenciador de mods e gravador de evidência em 1280×720 e 800×600.
- Captura automatizada de 25 segundos da rota de showcase.

### Alterado

- Versão do projeto, metadados de exportação, tag e documentação pública alinhados em `0.9.5-beta`.
- Evidência de capacidades e bloqueios consolidados em documentos mantidos.

### Segurança

- Artefatos públicos permanecem explicitamente sem assinatura; assinatura e notarização macOS continuam abertas.
- Checksums publicados para verificação independente.

## Desenvolvimento anterior

Antes do primeiro beta público, o repositório acumulou as superfícies atuais de movimento, combate, inventário, loot, geração procedural, ENet, editor, mods, UI e validação focada. Notas antigas foram consolidadas: atividade histórica não prova que o checkout atual esteja pronto para entrega.

[Não publicado]: https://github.com/rufl/MODUS/compare/v0.9.5-beta...HEAD
[0.9.5-beta]: https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta
