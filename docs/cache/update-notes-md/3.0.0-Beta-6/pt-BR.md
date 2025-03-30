Confira também as **mudanças interessantes** introduzidas no [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

**3.0.0 Beta 6** traz otimizações profundas e refinamentos, uma reformulação das configurações de rolagem, traduções para chinês e mais!

Aqui está tudo de novo:

## 1. Otimizações Profundas

Para este Beta, dediquei muito trabalho para extrair o máximo de desempenho do Mac Mouse Fix. E agora estou feliz em anunciar que, quando você clica em um botão do mouse no Beta 6, é **2x** mais rápido em comparação com o beta anterior! E a rolagem é ainda **4x** mais rápida!

Com o Beta 6, o MMF também desligará inteligentemente partes de si mesmo para economizar o máximo possível de CPU e bateria.

Por exemplo, quando você está usando um mouse com 3 botões mas só tem ações configuradas para botões não encontrados no seu mouse, como botões 4 e 5, o Mac Mouse Fix parará completamente de monitorar a entrada de botões do seu mouse. Significa 0% de uso de CPU quando você clica em um botão do mouse! Ou quando as configurações de rolagem no MMF correspondem às do sistema, o Mac Mouse Fix parará completamente de monitorar a entrada da roda de rolagem. Significa 0% de uso de CPU quando você rola! Mas se você configurar o recurso Command (⌘)-Scroll para Zoom, o Mac Mouse Fix começará a monitorar a entrada da roda de rolagem - mas apenas enquanto você mantiver pressionada a tecla Command (⌘). E assim por diante.
Então é realmente inteligente e só usará CPU quando necessário!

Isso significa que o MMF agora não é apenas o driver de mouse mais poderoso, fácil de usar e refinado para Mac, é também um dos, se não o mais otimizado e eficiente!

## 2. Tamanho do App Reduzido

Com 16 MB, o Beta 6 é aproximadamente 2x menor que o Beta 5!

Isso é um efeito colateral do abandono do suporte para versões mais antigas do macOS.

## 3. Abandono do Suporte para Versões Antigas do macOS

Tentei muito fazer o MMF 3 funcionar adequadamente em versões do macOS anteriores ao macOS 11 Big Sur. Mas a quantidade de trabalho para fazê-lo funcionar de forma refinada se mostrou avassaladora, então tive que desistir disso.

Daqui para frente, a versão mais antiga oficialmente suportada será o macOS 11 Big Sur.

O app ainda abrirá em versões mais antigas, mas haverá problemas visuais e talvez outros. O app não abrirá mais em versões do macOS anteriores ao 10.14.4. Isso é o que nos permite reduzir o tamanho do app em 2x, já que 10.14.4 é a versão mais antiga do macOS que inclui bibliotecas Swift modernas (Veja "Swift ABI Stability"), o que significa que essas bibliotecas Swift não precisam mais estar contidas no app.

## 4. Melhorias na Rolagem

O Beta 6 apresenta muitas melhorias na configuração e na interface dos novos sistemas de rolagem introduzidos no MMF 3.

### Interface

- Simplificou e encurtou bastante o texto da interface na aba Rolagem. A maioria das menções à palavra "Rolagem" foi removida, já que está implícita pelo contexto.
- Reformulou as configurações de suavidade da rolagem para serem muito mais claras e permitir algumas opções adicionais. Agora você pode escolher entre uma "Suavidade" "Desligada", "Regular" ou "Alta", substituindo o antigo botão "com Inércia". Acho que isso é muito mais claro e abriu espaço na interface para a nova opção "Simulação de Trackpad".
- Desativar a nova opção "Simulação de Trackpad" desativa o efeito elástico durante a rolagem, também impede a rolagem entre páginas no Safari e outros apps, e mais. Muitas pessoas ficaram incomodadas com isso, especialmente aquelas com rodas de rolagem livre como encontradas em alguns mouses Logitech como o MX Master, mas outros gostam, então decidi torná-lo uma opção. Espero que a apresentação do recurso esteja clara. Se você tiver alguma sugestão, me avise.
- Mudou a opção "Direção Natural de Rolagem" para "Inverter Direção de Rolagem". Isso significa que a configuração agora inverte a direção de rolagem do sistema e não é mais independente da direção de rolagem do sistema. Embora isso seja possivelmente uma experiência de usuário ligeiramente pior, essa nova forma de fazer as coisas nos permite implementar algumas otimizações e torna mais transparente para o usuário como desativar completamente o Mac Mouse Fix para rolagem.
- Melhorou a forma como as configurações de rolagem interagem com rolagem modificada em muitos casos diferentes. Por exemplo, a opção "Precisão" não se aplicará mais à ação "Clique e Rolagem" para "Desktop e Launchpad", já que é um obstáculo aqui em vez de ser útil.
- Melhorou a velocidade de rolagem ao usar "Clique e Rolagem" para "Desktop e Launchpad" ou "Aumentar ou Diminuir Zoom" e outros recursos.
- Removeu o link não funcional para as configurações de velocidade de rolagem do sistema na aba de rolagem que estava presente em versões do macOS anteriores ao macOS 13.0 Ventura. Não consegui encontrar uma maneira de fazer o link funcionar e não é extremamente importante.

### Sensação da Rolagem

- Melhorou a curva de animação para "Suavidade Regular" (anteriormente acessível desativando "com Inércia"). Isso torna as coisas mais suaves e responsivas.
- Melhorou a sensação de todas as configurações de velocidade de rolagem. As velocidades "Média" e "Rápida" estão mais rápidas. Há mais separação entre as velocidades "Baixa", "Média" e "Alta". A aceleração conforme você move a roda de rolagem mais rápido se sente mais natural e confortável ao usar a opção "Precisão".
- A forma como a velocidade de rolagem aumenta conforme você continua rolando em uma direção se sentirá mais natural e gradual. Estou usando novas curvas matemáticas para modelar a aceleração. O aumento de velocidade também será mais difícil de acionar acidentalmente.
- Não aumentando mais a velocidade de rolagem quando você continua rolando em uma direção ao usar a velocidade de rolagem "macOS".
- Restringiu o tempo de animação de rolagem a um máximo. Se a animação de rolagem naturalmente levaria mais tempo, ela será acelerada para ficar abaixo do tempo máximo. Dessa forma, rolar até a borda da página com uma roda de giro livre não fará o conteúdo da página se mover para fora da tela por tanto tempo. Isso não deve afetar a rolagem normal com uma roda que não gira livremente.
- Melhorou algumas interações em torno do efeito elástico ao rolar até a borda da página no Safari e outros apps.
- Corrigiu um problema onde "Clique e Rolagem" e outros recursos relacionados à rolagem não funcionavam corretamente após atualizar de uma versão muito antiga do painel de preferências do Mac Mouse Fix.
- Corrigiu um problema onde rolagens de pixel único eram enviadas com atraso ao usar a velocidade de rolagem "macOS" junto com rolagem suave.
- Corrigiu um bug onde a rolagem ainda estava muito rápida após soltar o modificador de Rolagem Rápida. Outras melhorias em torno de como a velocidade de rolagem é transferida de deslizes de rolagem anteriores.
- Melhorou a forma como a velocidade de rolagem aumenta com tamanhos maiores de tela

## 5. Notarização

A partir do 3.0.0 Beta 6, o Mac Mouse Fix será "Notarizado". Isso significa que não haverá mais mensagens sobre o Mac Mouse Fix ser potencialmente um "Software Malicioso" ao abrir o app pela primeira vez.

Notarizar seu app custa $100 por ano. Eu sempre fui contra isso, já que parecia hostil com software livre e de código aberto como o Mac Mouse Fix, e também parecia um passo perigoso em direção à Apple controlar e restringir o Mac como eles fazem com o iOS. Mas a falta de Notarização levou a problemas bastante graves, incluindo [várias situações](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) onde ninguém podia usar o app até eu lançar uma nova versão. Como o Mac Mouse Fix será monetizado agora, pensei que finalmente era apropriado Notarizar o app para uma experiência de usuário mais fácil e estável.

## 6. Traduções para Chinês

Mac Mouse Fix agora está disponível em Chinês!
Mais especificamente, está disponível em:

- Chinês Tradicional
- Chinês Simplificado
- Chinês (Hong Kong)

Muito obrigado ao @groverlynn por fornecer todas essas traduções e por atualizá-las durante os betas e se comunicar comigo. Veja seu pull request aqui: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Todo o Resto

Além das mudanças listadas acima, o Beta 6 também apresenta muitas melhorias menores.

- Removeu várias opções das Ações "Clique", "Clique e Segure" e "Clique e Rolagem" porque achei que eram redundantes já que a mesma funcionalidade pode ser alcançada de outras formas e isso limpa muito os menus. Trarei essas opções de volta se as pessoas reclamarem. Então se você sente falta dessas opções - por favor reclame.
- A direção de Clique e Arraste agora corresponderá à direção do gesto do trackpad mesmo quando "Rolagem Natural" estiver desativada em Configurações do Sistema > Trackpad. Antes, Clique e Arraste sempre se comportava como deslizar no trackpad com "Rolagem Natural" *ativada*.
- Corrigiu um problema onde os cursores desapareciam e depois reapareciam em outro lugar ao usar uma Ação "Clique e Arraste" durante uma gravação de tela ou ao usar o software DisplayLink.
- Corrigiu o centralização do "+" no Campo "+" na aba Botões
- Várias melhorias visuais na aba Botões. A paleta de cores do Campo "+" e da Tabela de Ações foi refeita para parecer correta ao usar a opção "Permitir coloração do papel de parede nas janelas" do macOS. As bordas da Tabela de Ações agora têm uma cor transparente que parece mais dinâmica e se ajusta ao seu ambiente.
- Fez com que quando você adiciona muitas ações à tabela de ações e a janela do Mac Mouse Fix cresce, ela crescerá exatamente do tamanho da tela (ou da tela menos o dock se você não tiver o ocultamento do dock ativado) e então parará. Quando você adicionar ainda mais ações, a tabela de ações começará a rolar.
- Este Beta agora suporta um novo checkout onde você pode comprar uma licença em dólares americanos como anunciado. Antes você só podia comprar uma licença em Euros. As antigas licenças em Euro ainda serão suportadas, é claro.
- Corrigiu um problema onde a rolagem com momento às vezes não era iniciada ao usar o recurso "Rolar e Navegar".
- Quando a janela do Mac Mouse Fix se redimensiona durante uma mudança de aba, ela agora se reposicionará para não sobrepor o Dock
- Corrigiu cintilação em alguns elementos da interface ao mudar da aba Botões para outra aba
- Melhorou a aparência da animação que o Campo "+" reproduz após gravar uma entrada. Especialmente em versões do macOS anteriores ao Ventura, onde a sombra do Campo "+" apareceria com falhas durante a animação.
- Desativou notificações listando vários botões que foram capturados/não são mais capturados pelo Mac Mouse Fix que apareceriam ao iniciar o app pela primeira vez ou ao carregar uma predefinição. Achei que essas mensagens eram distrativas e ligeiramente avassaladoras e não muito úteis nesses contextos.
- Reformulou a Tela de Concessão de Acessibilidade. Agora mostrará informações sobre por que o Mac Mouse Fix precisa de Acesso à Acessibilidade diretamente em vez de vincular ao site e está um pouco mais clara e tem um layout mais agradável visualmente.
- Atualizou o link de Agradecimentos na aba Sobre.
- Melhorou as mensagens de erro quando o Mac Mouse Fix não pode ser ativado porque há outra versão presente no sistema. A mensagem agora será exibida em uma janela de alerta flutuante que sempre permanece no topo de outras janelas até ser descartada, em vez de uma Notificação Toast que desaparece ao clicar em qualquer lugar. Isso deve facilitar o seguimento dos passos de solução sugeridos.
- Corrigiu alguns problemas com a renderização de markdown em versões do macOS anteriores ao Ventura. MMF agora usará uma solução de renderização de markdown personalizada para todas as versões do macOS, incluindo Ventura. Antes estávamos usando uma API do sistema introduzida no Ventura, mas isso levava a inconsistências. Markdown é usado para adicionar links e ênfase ao texto em toda a interface.
- Poliu as interações em torno da ativação do acesso à acessibilidade.
- Corrigiu um problema onde a janela do app às vezes abria sem mostrar nenhum conteúdo até você mudar para uma das abas.
- Corrigiu um problema com o Campo "+" onde às vezes você não podia adicionar uma nova ação mesmo que mostrasse um efeito de hover indicando que você pode inserir uma ação.
- Corrigiu um deadlock e vários outros pequenos problemas que às vezes aconteciam ao mover o ponteiro do mouse dentro do Campo "+"
- Corrigiu um problema onde um popover que aparece na aba Botões quando seu mouse não parece se adequar às configurações atuais de botões às vezes teria todo o texto em negrito.
- Atualizou todas as menções da antiga licença MIT para a nova licença MMF. Novos arquivos criados para o projeto agora conterão um cabeçalho gerado automaticamente mencionando a licença MMF.
- Fez a mudança para a aba Botões ativar o MMF para Rolagem. Caso contrário, você não poderia gravar gestos de Clique e Rolagem.
- Corrigiu alguns problemas onde nomes de botões não estavam sendo exibidos corretamente na Tabela de Ações em algumas situações.
- Corrigiu bug onde a seção de teste na tela Sobre ficaria com problemas ao abrir o app e depois mudar para a aba de teste após o teste expirar.
- Corrigiu um bug onde o link Ativar Licença na seção de teste da Aba Sobre às vezes não reagia a cliques.
- Corrigiu um vazamento de memória ao usar o recurso "Clique e Arraste" para "Spaces e Mission Control".
- Ativou runtime endurecido no app principal Mac Mouse Fix, melhorando a segurança
- Muita limpeza de código, reestruturação do projeto
- Vários outros crashes corrigidos
- Vários vazamentos de memória corrigidos
- Vários pequenos ajustes de texto na interface
- Reformulações de vários sistemas internos também melhoraram a robustez e o comportamento em casos extremos

## 8. Como Você Pode Ajudar

Você pode ajudar compartilhando suas **ideias**, **problemas** e **feedback**!

O melhor lugar para compartilhar suas **ideias** e **problemas** é o [Assistente de Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
O melhor lugar para dar feedback **rápido** não estruturado é a [Discussão de Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Você também pode acessar esses lugares de dentro do app na aba "**ⓘ Sobre**".

**Obrigado** por ajudar a fazer o Mac Mouse Fix ser o melhor possível! 🙌:)