Confere também as **alterações interessantes** introduzidas no [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

O **3.0.0 Beta 6** traz otimizações profundas e aperfeiçoamentos, uma reformulação das configurações de scroll, traduções para chinês e mais!

Aqui está tudo o que há de novo:

## 1. Otimizações Profundas

Para este Beta, dediquei muito trabalho para extrair o máximo de desempenho do Mac Mouse Fix. E agora tenho o prazer de anunciar que, quando clicas num botão do rato no Beta 6, é **2x** mais rápido em comparação com o beta anterior! E o scroll é ainda **4x** mais rápido!

Com o Beta 6, o MMF também desligará inteligentemente partes de si mesmo para poupar o máximo possível de CPU e bateria.

Por exemplo, quando estás a usar um rato com 3 botões mas só tens ações configuradas para botões que não existem no teu rato, como os botões 4 e 5, o Mac Mouse Fix deixará completamente de monitorizar os cliques do teu rato. Significa 0% de uso de CPU quando clicas num botão do teu rato! Ou quando as configurações de scroll no MMF correspondem às do sistema, o Mac Mouse Fix deixará de monitorizar completamente o input da roda de scroll. Significa 0% de uso de CPU quando fazes scroll! Mas se configurares a funcionalidade Command (⌘)-Scroll para Zoom, o Mac Mouse Fix começará a monitorizar o input da roda de scroll - mas apenas enquanto mantiveres pressionada a tecla Command (⌘). E assim por diante.
Portanto, é realmente inteligente e só usará CPU quando for necessário!

Isto significa que o MMF não é apenas o controlador de rato mais poderoso, fácil de usar e aperfeiçoado para Mac, é também um dos, se não o, mais otimizado e eficiente!

## 2. Tamanho da App Reduzido

Com 16 MB, o Beta 6 é cerca de 2x menor que o Beta 5!

Isto é um efeito secundário do fim do suporte para versões mais antigas do macOS.

## 3. Fim do Suporte para Versões Antigas do macOS

Tentei arduamente fazer o MMF 3 funcionar adequadamente em versões do macOS anteriores ao macOS 11 Big Sur. Mas a quantidade de trabalho para o tornar polido revelou-se avassaladora, então tive de desistir.

Daqui para a frente, a versão mais antiga oficialmente suportada será o macOS 11 Big Sur.

A app ainda abrirá em versões mais antigas, mas haverá problemas visuais e possivelmente outros. A app não abrirá mais em versões do macOS anteriores à 10.14.4. Isto é o que nos permite reduzir o tamanho da app em 2x, já que a 10.14.4 é a versão mais antiga do macOS que inclui bibliotecas Swift modernas (Ver "Swift ABI Stability"), o que significa que essas bibliotecas Swift já não precisam de estar contidas na app.

## 4. Melhorias no Scroll

O Beta 6 apresenta muitas melhorias na configuração e na interface dos novos sistemas de scroll introduzidos no MMF 3.

### Interface

- Simplificou e encurtou bastante o texto da interface no separador Scroll. A maioria das menções à palavra "Scroll" foram removidas já que está implícito pelo contexto.
- Reformulou as configurações de suavidade do scroll para serem muito mais claras e permitirem algumas opções adicionais. Agora podes escolher entre uma "Suavidade" "Desligada", "Regular" ou "Alta", substituindo o antigo interruptor "com Inércia". Penso que isto é muito mais claro e criou espaço na interface para a nova opção "Simulação de Trackpad".
- Desligar a nova opção "Simulação de Trackpad" desativa o efeito elástico durante o scroll, também impede o scroll entre páginas no Safari e outras apps, e mais. Muitas pessoas ficavam incomodadas com isto, especialmente aquelas com rodas de scroll de rotação livre como as encontradas em alguns ratos Logitech como o MX Master, mas outras gostam, então decidi torná-lo uma opção. Espero que a apresentação da funcionalidade esteja clara. Se tiveres alguma sugestão, avisa-me.
- Alterou a opção "Direção Natural do Scroll" para "Inverter Direção do Scroll". Isto significa que a configuração agora inverte a direção do scroll do sistema e já não é independente da direção do scroll do sistema. Embora isto seja possivelmente uma experiência de utilizador ligeiramente pior, esta nova forma de fazer as coisas permite-nos implementar algumas otimizações e torna mais transparente para o utilizador como desligar completamente o Mac Mouse Fix para o scroll.
- Melhorou a forma como as configurações de scroll interagem com o scroll modificado em muitos casos extremos. Por exemplo, a opção "Precisão" já não se aplicará ao "Clicar e Scroll" para a ação "Ambiente de Trabalho e Launchpad" já que é um obstáculo aqui em vez de ser útil.
- Melhorou a velocidade do scroll ao usar "Clicar e Scroll" para "Ambiente de Trabalho e Launchpad" ou "Aumentar ou Diminuir Zoom" e outras funcionalidades.
- Removeu o link não funcional para as configurações de velocidade do scroll do sistema no separador scroll que estava presente em versões do macOS anteriores ao macOS 13.0 Ventura. Não consegui encontrar uma forma de fazer o link funcionar e não é extremamente importante.

### Sensação do Scroll

- Melhorou a curva de animação para "Suavidade Regular" (anteriormente acessível desligando "com Inércia"). Isto torna as coisas mais suaves e responsivas.
- Melhorou a sensação de todas as configurações de velocidade do scroll. As velocidades "Média" e "Rápida" estão mais rápidas. Há mais separação entre as velocidades "Baixa", "Média" e "Alta". A aceleração à medida que moves a roda do scroll mais rapidamente sente-se mais natural e confortável quando usas a opção "Precisão".
- A forma como a velocidade do scroll aumenta à medida que continuas a fazer scroll numa direção sentir-se-á mais natural e gradual. Estou a usar novas curvas matemáticas para modelar a aceleração. O aumento de velocidade também será mais difícil de ativar acidentalmente.
- Já não aumenta a velocidade do scroll quando continuas a fazer scroll numa direção enquanto usas a velocidade de scroll "macOS".
- Restringiu o tempo de animação do scroll a um máximo. Se a animação do scroll naturalmente demorasse mais tempo, será acelerada para ficar abaixo do tempo máximo. Desta forma, fazer scroll até à extremidade da página com uma roda de rotação livre não fará o conteúdo da página mover-se para fora do ecrã durante tanto tempo. Isto não deve afetar o scroll normal com uma roda sem rotação livre.
- Melhorou algumas interações em torno do efeito elástico ao fazer scroll até à extremidade de uma página no Safari e outras apps.
- Corrigiu um problema onde "Clicar e Scroll" e outras funcionalidades relacionadas com scroll não funcionavam corretamente após atualizar de uma versão muito antiga do painel de preferências do Mac Mouse Fix.
- Corrigiu um problema onde scrolls de um pixel eram enviados com atraso ao usar a velocidade de scroll "macOS" junto com o scroll suave.
- Corrigiu um bug onde o scroll ainda estava muito rápido após libertar o modificador de Scroll Rápido. Outras melhorias em torno de como a velocidade do scroll é transportada de deslizes de scroll anteriores.
- Melhorou a forma como a velocidade do scroll aumenta com tamanhos de ecrã maiores.

## 5. Notarização

A partir do 3.0.0 Beta 6, o Mac Mouse Fix será "Notarizado". Isso significa que não haverá mais mensagens sobre o Mac Mouse Fix ser potencialmente "Software Malicioso" ao abrir a app pela primeira vez.

Notarizar a tua app custa $100 por ano. Sempre fui contra isto, já que parecia hostil para software gratuito e de código aberto como o Mac Mouse Fix, e também parecia um passo perigoso em direção à Apple controlar e bloquear o Mac como fazem com o iOS. Mas a falta de Notarização levou a problemas bastante graves, incluindo [várias situações](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) onde ninguém podia usar a app até eu lançar uma nova versão. Como o Mac Mouse Fix será monetizado agora, pensei que finalmente era apropriado Notarizar a app para uma experiência de utilizador mais fácil e estável.

## 6. Traduções para Chinês

O Mac Mouse Fix está agora disponível em Chinês!
Mais especificamente, está disponível em:

- Chinês Tradicional
- Chinês Simplificado
- Chinês (Hong Kong)

Um enorme obrigado ao @groverlynn por fornecer todas estas traduções, bem como por atualizá-las durante os betas e comunicar comigo. Vê o seu pull request aqui: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Todo o Resto

Além das alterações listadas acima, o Beta 6 também apresenta muitas melhorias menores.

- Removeu várias opções das Ações "Clicar", "Clicar e Manter" e "Clicar e Scroll" porque achei que eram redundantes já que a mesma funcionalidade pode ser alcançada de outras formas e isto limpa muito os menus. Trarei essas opções de volta se as pessoas reclamarem. Então se sentires falta dessas opções - por favor reclama.
- A direção de Clicar e Arrastar agora corresponderá à direção do deslize do trackpad mesmo quando "Scroll Natural" estiver desligado nas Definições do Sistema > Trackpad. Antes, Clicar e Arrastar sempre se comportava como deslizar no trackpad com "Scroll Natural" *ligado*.
- Corrigiu um problema onde os cursores desapareciam e depois reapareciam noutro lugar ao usar uma Ação "Clicar e Arrastar" durante uma gravação de ecrã ou ao usar o software DisplayLink.
- Corrigiu o centramento do "+" no Campo "+" no separador Botões
- Várias melhorias visuais no separador botões. A paleta de cores do Campo "+" e da Tabela de Ações foi reformulada para parecer correta ao usar a opção "Permitir coloração do papel de parede nas janelas" do macOS. As bordas da Tabela de Ações agora têm uma cor transparente que parece mais dinâmica e ajusta-se ao seu ambiente.
- Fez com que quando adicionas muitas ações à tabela de ações e a janela do Mac Mouse Fix cresce, ela crescerá exatamente do tamanho do ecrã (ou do ecrã menos a dock se não tiveres o ocultamento da dock ativado) e depois para. Quando adicionares ainda mais ações, a tabela de ações começará a fazer scroll.
- Este Beta agora suporta um novo checkout onde podes comprar uma licença em dólares americanos como anunciado. Antes só podias comprar uma licença em Euros. As antigas licenças em Euros continuarão a ser suportadas, claro.
- Corrigiu um problema onde o scroll com momentum às vezes não era iniciado ao usar a funcionalidade "Scroll e Navegar".
- Quando a janela do Mac Mouse Fix se redimensiona durante uma mudança de separador, agora reposicionar-se-á para não se sobrepor à Dock
- Corrigiu a cintilação em alguns elementos da interface ao mudar do separador Botões para outro separador
- Melhorou a aparência da animação que o Campo "+" reproduz após gravar um input. Especialmente em versões do macOS anteriores ao Ventura, onde a sombra do Campo "+" apareceria com falhas durante a animação.
- Desativou notificações listando vários botões que foram capturados/já não são capturados pelo Mac Mouse Fix que apareceriam ao iniciar a app pela primeira vez ou ao carregar uma predefinição. Achei que estas mensagens eram distrativas e ligeiramente avassaladoras e não muito úteis nesses contextos.
- Reformulou o Ecrã de Concessão de Acessibilidade. Agora mostrará informações sobre por que o Mac Mouse Fix precisa de Acesso à Acessibilidade diretamente em vez de ligar ao website e está um pouco mais claro e tem um layout visualmente mais agradável.
- Atualizou o link de Agradecimentos no separador Sobre.
- Melhorou as mensagens de erro quando o Mac Mouse Fix não pode ser ativado porque há outra versão presente no sistema. A mensagem agora será exibida numa janela de alerta flutuante que sempre permanece no topo de outras janelas até ser descartada em vez de uma Notificação Toast que desaparece ao clicar em qualquer lugar. Isto deve tornar mais fácil seguir os passos de solução sugeridos.
- Corrigiu alguns problemas com a renderização de markdown em versões do macOS anteriores ao Ventura. O MMF agora usará uma solução de renderização de markdown personalizada para todas as versões do macOS, incluindo Ventura. Antes estávamos a usar uma API do sistema introduzida no Ventura mas isso levava a inconsistências. Markdown é usado para adicionar links e ênfase ao texto em toda a interface.
- Aperfeiçoou as interações em torno da ativação do acesso à acessibilidade.
- Corrigiu um problema onde a janela da app às vezes abria sem mostrar nenhum conteúdo até mudares para um dos separadores.
- Corrigiu um problema com o Campo "+" onde às vezes não podias adicionar uma nova ação mesmo que mostrasse um efeito de hover indicando que podes inserir uma ação.
- Corrigiu um deadlock e vários outros pequenos problemas que às vezes aconteciam ao mover o ponteiro do rato dentro do Campo "+"
- Corrigiu um problema onde um popover que aparece no separador Botões quando o teu rato não parece corresponder às configurações atuais de botões às vezes teria todo o texto em negrito.
- Atualizou todas as menções da antiga licença MIT para a nova licença MMF. Novos ficheiros criados para o projeto agora conterão um cabeçalho gerado automaticamente mencionando a licença MMF.
- Fez com que mudar para o separador Botões ative o MMF para Scroll. Caso contrário, não poderias gravar gestos de Clicar e Scroll.
- Corrigiu alguns problemas onde nomes de botões não estavam a ser exibidos corretamente na Tabela de Ações em algumas situações.
- Corrigiu um bug onde a seção de teste no ecrã Sobre ficaria com falhas ao abrir a app e depois mudar para o separador de teste após o teste expirar.
- Corrigiu um bug onde o link Ativar Licença na seção de teste do Separador Sobre às vezes não reagia a cliques.
- Corrigiu uma fuga de memória ao usar a funcionalidade "Clicar e Arrastar" para "Spaces e Mission Control".
- Ativou runtime endurecido na app principal do Mac Mouse Fix, melhorando a segurança
- Muita limpeza de código, reestruturação do projeto
- Vários outros crashes corrigidos
- Várias fugas de memória corrigidas
- Vários pequenos ajustes nas strings da interface
- Reformulações de vários sistemas internos também melhoraram a robustez e o comportamento em casos extremos

## 8. Como Podes Ajudar

Podes ajudar partilhando as tuas **ideias**, **problemas** e **feedback**!

O melhor lugar para partilhar as tuas **ideias** e **problemas** é o [Assistente de Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
O melhor lugar para dar feedback **rápido** não estruturado é a [Discussão de Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Também podes aceder a estes lugares dentro da app no separador "**ⓘ Sobre**".

**Obrigado** por ajudares a tornar o Mac Mouse Fix o melhor possível! 🙌:)