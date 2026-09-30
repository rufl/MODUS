# Backlog do MODUS

> **Documentation status: maintained reference.** Prioridades atualizadas em 2026-09-30 e ordenadas pelo risco de entrega. Histórico concluído pertence ao changelog; código implementado só conclui uma tarefa quando a fronteira de aceitação está definida.

## Bloqueios para beta estável

- [ ] Assinar artefatos Windows e Linux com identidade de entrega documentada.
- [ ] Assinar e notarizar o aplicativo universal macOS.
- [ ] Concluir aceitação nativa de instalação, startup, entrada, save e remoção no Windows e macOS.
- [ ] Executar sessões ENet com latência, jitter, perda de pacotes, reconexão e late join representativos.
- [ ] Exercitar validação de autoridade com tráfego malformado e hostil.
- [ ] Definir orçamentos para CPU/GPU de entrada e soak repetível de sessão longa.
- [ ] Publicar política de compatibilidade para mods, schemas e saves.

## Gameplay e mundos

- [ ] Ajustar movimento, armas, leitura de inimigos e ritmo por meio de sessões observadas.
- [ ] Ampliar encontros autorais sem esconder falhas procedurais atrás de caminhos roteirizados.
- [ ] Amostrar mais sementes procedurais e registrar falhas junto com a semente.
- [ ] Validar memória e cancelamento de workers em transições repetidas.
- [ ] Adicionar um loop de campanha apenas após estabilizar save e versionamento de conteúdo.

## Multijogador

- [ ] Validar servidor dedicado e clientes nas plataformas de entrega.
- [ ] Registrar inventário, dano, respawn e transições autoritativos com múltiplos peers.
- [ ] Medir banda e correções sob latência e perda representativas.
- [ ] Definir orientação pública de hospedagem, portas, compatibilidade e moderação.
- [ ] Provar duas contas Steam, relay/P2P e Workshop antes de apresentar esses caminhos como suportados.

## Criação e mods

- [ ] Completar aceitação gráfica do editor embutido exportado e do editor standalone.
- [ ] Validar round trips `.mdsl` em mais estruturas de mapas.
- [ ] Definir dependências, conflitos, versões e falhas de mods.
- [ ] Documentar limites seguros de conteúdo e garantias de sandbox.
- [ ] Publicar exemplos somente com licenças e caminhos de atualização claros.

## Acessibilidade e usabilidade

- [ ] Auditar menus e editor segundo princípios WCAG 2.2 de teclado, foco, contraste e redimensionamento.
- [ ] Verificar navegação completa apenas por teclado e apenas por controle.
- [ ] Adicionar remapeamento e feedback que não dependa somente de cor.
- [ ] Definir extração de localização e expansão de layout.
- [ ] Testar 16:10, ultrawide, baixa resolução e desktop escalado.

## Experiência de contribuição

- [ ] Manter setup e verificação executáveis a partir de clone limpo.
- [ ] Criar issues iniciais apenas com owner, aceitação e dependências visíveis.
- [ ] Reduzir superfícies amplas do `GameManager` quando trabalho real revelar uma fronteira estável.
- [ ] Revisar dependências, proveniência de assets e afirmações antes de cada release candidate.

## Critério de conclusão

Uma tarefa sai do backlog apenas quando:

1. o resultado visível existe;
2. a menor verificação representativa foi observada;
3. limitações e fronteiras de plataforma foram documentadas;
4. nenhuma credencial, asset proprietário ou detalhe de infraestrutura privada é necessário para reproduzi-la.
