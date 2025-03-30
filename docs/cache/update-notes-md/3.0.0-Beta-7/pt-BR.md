Confira também as **melhorias interessantes** introduzidas no [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6)!


---

**3.0.0 Beta 7** traz várias pequenas melhorias e correções de bugs.

Aqui está tudo de novo:

**Melhorias**

- Adicionadas **traduções para coreano**. Muito obrigado ao @jeongtae! (Encontre-o no [GitHub](https://github.com/jeongtae))
- Tornou a **rolagem** com a opção 'Suavidade: Alta' **ainda mais suave**, mudando a velocidade apenas gradualmente, em vez de ter saltos repentinos na velocidade de rolagem conforme você move a roda de rolagem. Isso deve fazer a rolagem parecer um pouco mais suave e mais fácil de acompanhar com os olhos sem tornar as coisas menos responsivas. A rolagem com 'Suavidade: Alta' usa cerca de 30% mais CPU agora, no meu computador passou de 1,2% de uso de CPU durante rolagem contínua para 1,6%. Então a rolagem ainda é altamente eficiente e espero que isso não faça diferença para ninguém. Muito obrigado ao [MOS](https://mos.caldis.me/), que inspirou este recurso e cujo 'Scroll Monitor' eu usei para ajudar a implementar o recurso.
- O Mac Mouse Fix agora está **processando entradas de botões de todas as fontes**. Antes, o Mac Mouse Fix só processava entradas de mouses que reconhecia. Acho que isso pode ajudar na compatibilidade com certos mouses em casos específicos, como ao usar um Hackintosh, mas também fará com que o Mac Mouse Fix capture entradas de botões geradas artificialmente por outros aplicativos, o que pode levar a problemas em outros casos específicos. Me avise se isso causar algum problema para você, e eu resolverei isso em atualizações futuras.
- Refinado o toque e o polimento dos gestos 'Clique e Rolagem' para 'Desktop e Launchpad' e 'Clique e Rolagem' para 'Mover Entre Spaces'.
- Agora levando em conta a densidade de informação de um idioma ao calcular o **tempo que as notificações são exibidas**. Antes disso, as notificações permaneciam visíveis por um tempo muito curto em idiomas com alta densidade de informação como chinês ou coreano.
- Habilitados **diferentes gestos** para mover entre **Spaces**, abrir o **Mission Control** ou abrir o **App Exposé**. No Beta 6, eu fiz com que essas ações estivessem disponíveis apenas através do gesto 'Clique e Arraste' - como um experimento para ver quantas pessoas realmente se importavam em poder acessar essas ações de outras maneiras. Parece que algumas se importam, então agora tornei possível novamente acessar essas ações através de um simples 'Clique' de um botão ou através de 'Clique e Rolagem'.
- Tornou possível **Rotacionar** através de um gesto de **Clique e Rolagem**.
- **Melhorou** a forma como a opção de **Simulação do Trackpad** funciona em alguns cenários. Por exemplo, ao rolar horizontalmente para excluir uma mensagem no Mail, a direção em que a mensagem se move agora está invertida, o que espero que pareça um pouco mais natural e consistente para a maioria das pessoas.
- Adicionado um recurso para **remapear** para **Clique Primário** ou **Clique Secundário**. Implementei isso porque o botão direito do meu mouse favorito quebrou. Essas opções estão ocultas por padrão. Você pode vê-las mantendo pressionada a tecla Option ao selecionar uma ação.
  - Isso atualmente não possui traduções para chinês e coreano, então se você quiser contribuir com traduções para esses recursos, isso seria muito apreciado!

**Correções de Bugs**

- Corrigido um bug onde a **direção do 'Clique e Arraste'** para 'Mission Control e Spaces' estava **invertida** para pessoas que nunca alternaram a opção 'Rolagem natural' nas Configurações do Sistema. Agora, a direção dos gestos 'Clique e Arraste' no Mac Mouse Fix deve sempre corresponder à direção dos gestos no seu Trackpad ou Magic Mouse. Se você quiser uma opção separada para inverter a direção do 'Clique e Arraste', em vez de seguir as Configurações do Sistema, me avise.
- Corrigido um bug onde os **dias gratuitos** **contavam muito rapidamente** para alguns usuários. Se você foi afetado por isso, me avise e verei o que posso fazer.
- Corrigido um problema no macOS Sonoma onde a barra de abas não era exibida corretamente.
- Corrigida instabilidade ao usar velocidade de rolagem 'macOS' enquanto usa 'Clique e Rolagem' para abrir o Launchpad.
- Corrigido travamento onde o aplicativo 'Mac Mouse Fix Helper' (que roda em segundo plano quando o Mac Mouse Fix está ativado) travava às vezes ao gravar um atalho de teclado.
- Corrigido um bug onde o Mac Mouse Fix travava ao tentar capturar eventos artificiais gerados pelo [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma)
- Corrigido um problema onde o nome de alguns mouses exibidos no diálogo 'Restaurar Padrões...' continha o fabricante duas vezes.
- Diminuída a probabilidade do 'Clique e Arraste' para 'Mission Control e Spaces' ficar travado quando o computador está lento.
- Corrigido o uso de 'Force Touch' nas strings da interface onde deveria ser 'Force click'.
- Corrigido um bug que ocorria em certas configurações, onde abrir o Launchpad ou mostrar o Desktop através de 'Clique e Rolagem' não funcionava se você soltasse o botão enquanto a animação de transição ainda estava em andamento.

**Mais**

- Várias melhorias internas, melhorias de estabilidade, limpeza interna e mais.

## Como Você Pode Ajudar

Você pode ajudar compartilhando suas **ideias**, **problemas** e **feedback**!

O melhor lugar para compartilhar suas **ideias** e **problemas** é o [Assistente de Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
O melhor lugar para dar **feedback** rápido e não estruturado é a [Discussão de Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Você também pode acessar esses lugares de dentro do aplicativo na aba '**ⓘ Sobre**'.

**Obrigado** por ajudar a tornar o Mac Mouse Fix melhor! 😎:)