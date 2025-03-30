**3.0.0** será a **maior atualização** do Mac Mouse Fix até agora!

Reunindo vários recursos nos quais trabalhei por muito tempo para finalmente entregar esta incrível **proposta de valor**:

**Torne seu mouse de $10 melhor que um Trackpad da Apple!**

E você pode **testar agora**! Estou muito animado para ouvir o feedback de vocês!

Aqui está **tudo que há de novo**:

## 1. Clique e Arraste para Rolar

Agora você pode **Clicar e Arrastar para Rolar** livremente em qualquer direção!

Também permite voltar e avançar no **Safari**, marcar mensagens como lidas no **Mail**, e **fazer qualquer outra coisa** que você pode fazer com um **gesto de dois dedos** em um **Trackpad da Apple**!

Trabalhei duro para implementar o recurso com este padrão de qualidade. Mas como resultado, enquanto você experimenta, acho que vai perceber que realmente "**simplesmente funciona**"!

## 2. Gestos de Rolagem

O Mac Mouse Fix agora suporta **Gestos de Rolagem**!
Isso significa que você pode **acionar ações** **rolando** enquanto mantém pressionado um botão do mouse!

Os Gestos de Rolagem permitem que você obtenha ainda **mais funcionalidades** de um único botão do mouse de forma super **intuitiva**.

Neste beta, existem os **seguintes** Gestos de Rolagem:

  - **Desktop & Launchpad** permite revelar o Desktop ou abrir o Launchpad rolando para cima ou para baixo. Isso é super fluido e intuitivo porque simula o gesto de pinça com 4 dedos em um Trackpad da Apple.
  - **Mover entre Spaces** permite alternar entre Spaces rolando para cima ou para baixo. Isso também é super fluido já que simula o deslizar com 3 dedos em um Trackpad da Apple. No entanto, não tenho certeza se isso é redundante já que você já pode Clicar e Arrastar para mover entre Spaces. Me diga o que você acha!
  - **Aumentar ou diminuir zoom** permite dar uma olhada mais de perto na web ou em outros lugares. Isso já estava disponível no Mac Mouse Fix 2 mantendo a tecla Command (⌘) pressionada enquanto rolava, mas agora você pode fazer isso mais facilmente usando apenas uma mão!
  - **Rolagem Horizontal** permite rolar para a esquerda e direita. Você também pode usá-la para navegar entre páginas no Safari e outros apps porque simula o deslizar com 2 dedos em um Trackpad da Apple.
  - **Rolagem Rápida** permite rolar grandes distâncias com mínimo esforço.
  - **Rolagem Precisa** permite rolar pequenas distâncias e usar elementos de interface sensíveis como controles deslizantes de volume com precisão.
  - **Alternador de Apps** permite alternar entre apps recentes, assim como pressionar Command-Tab (⌘ + ↹) no seu teclado. Este recurso tem alguns bugs e não tenho certeza se é muito útil, já que você já pode acessar facilmente o Alternador de Abas pelo teclado, então provavelmente vou removê-lo depois. Mas me diga o que você acha.

## 3. Rolagem Inercial

A **Rolagem Inercial** faz a rolagem no seu mouse parecer tão **rápida** e **fluida** quanto um Trackpad da Apple.

A Rolagem Inercial cria animações **longas** e muito **suaves**. Em uma roda de rolagem, animações longas geralmente vêm com a desvantagem de menos controle.

Mas o Mac Mouse Fix 3 implementa alguns **algoritmos inteligentes** para dar uma **ótima sensação inercial** enquanto ainda oferece muito **controle**.

A propósito, se você baixar este Beta, acho que será **uma das primeiras** pessoas a usar o **efeito bounce na rolagem** com um mouse! (além do Magic Mouse) Acho isso meio legal.

## 4. Outras Melhorias na Rolagem

Eu **reescrevi** a maior parte do código de rolagem para o MMF 3. Isso me permitiu implementar muitos **outros pequenos recursos** e melhorias:

1. Agora existem **2 modificadores de teclado adicionais** então você pode não apenas **Aumentar ou diminuir zoom** com Command (⌘), e **Rolar Horizontalmente** com Shift (⇧), mas também **Rolar Rapidamente** com Control (^) e **Rolar com Precisão** com Option (⌥).
2. Agora você pode ver e **personalizar todos os 4 modificadores de teclado** usando uma nova interface bonita e intuitiva.
3. **Rolagem Precisa Sempre Ativa** permite rolar com precisão mesmo sem segurar uma tecla modificadora movendo a roda de rolagem lentamente.
4. **Entrada de Rolagem Horizontal** do seu mouse não é mais ignorada, mas sim suavizada e invertida como a entrada de rolagem vertical normal. Se seu mouse tem uma **roda inclinável** ou uma **roda de rolagem horizontal** deve se sentir muito melhor agora.
5. As **Configurações de Inversão da Direção de Rolagem** agora são independentes das Configurações do Sistema permitindo uma interface menos complicada.
6. **Configurações de rolagem** agora podem ser **combinadas** mais livremente. Por exemplo, você pode usar a Velocidade de Rolagem do **Mac Mouse Fix** mesmo quando a Rolagem Suave está **desativada**. Ou você pode usar a Velocidade de Rolagem do **macOS** quando a Rolagem Suave está **ativada**. (Nota: Pessoalmente não gosto nada da Velocidade de Rolagem do macOS e não consigo pensar em motivos pelos quais alguém a preferiria. Então se você preferir, eu ficaria muito interessado em saber mais sobre sua experiência! Você pode entrar em contato através da aba "**ⓘ Sobre**".)

## 5. Item da Barra de Menu

O Mac Mouse Fix agora tem um **Item na Barra de Menu** para que você sempre possa ver quando está ativado!

O Item da Barra de Menu tem um **ícone bonito**, e também permite **desativar rapidamente** certos recursos do Mac Mouse Fix para que você possa jogar um jogo ou usar um app sem que o Mac Mouse Fix interfira.

Claro, você também ainda pode **desativá-lo** para uma Barra de Menu mais limpa.

## 6. Configurações Específicas por App Foram Removidas

As **Configurações Específicas por App** foram removidas por enquanto. No entanto, planejo **trazê-las de volta** em uma forma muito mais robusta e poderosa no futuro.

Por enquanto, acho que as configurações rápidas na **Barra de Menu** são uma solução **melhor**, mesmo que menos conveniente.

Elas **resolvem** os **problemas mais importantes** das antigas Configurações Específicas por App:

- Configurações Específicas por App não funcionavam com alguns programas como **executáveis de linha de comando**. Isso incluía apps populares como **Minecraft**.
- Configurações Específicas por App tinham muitas limitações como não permitir **desligar botões** completamente, o que era um problema para muitos jogadores.

Outra coisa a considerar é que as antigas Configurações Específicas por App foram originalmente **projetadas como uma solução temporária** para alguns apps serem incompatíveis com o antigo sistema de rolagem. Mas agora, com o novo sistema de rolagem emulando precisamente os Toques de Rolagem vindos de um Trackpad da Apple, a maioria dessas incompatibilidades deve estar **resolvida de qualquer forma**! Então deve haver menos necessidade do que as antigas Configurações Específicas por App faziam melhor.

Espero que todos estejam ok com isso! Me digam seus **pensamentos**!

## 7. Reformulação da Interface

Eu **reescrevi completamente a interface** para ser mais **bonita** e **poderosa** enquanto ainda mantém a **simplicidade** e **facilidade de uso** que as pessoas amam no Mac Mouse Fix.

Aqui está o que há de novo:

- A interface agora está dividida em diferentes **abas**. Isso organiza as coisas e permite que o Mac Mouse Fix forneça configurações adicionais importantes para as pessoas sem que a interface se torne muito complicada ou sobrecarregada. Isso também me permitirá estender o Mac Mouse Fix com novos recursos no futuro.
- Adicionei pequenas e agradáveis **animações** por toda a nova interface que tornam mais fácil navegar e adicionam uma sensação de polimento.
- Opções que dependem de outras opções serão **ocultadas** e o layout se ajustará com belas animações sutis. Isso mantém as coisas o mais simples e otimizadas possível. Assim você não precisa gastar tempo e poder mental olhando para opções que não precisa pensar sobre.
- A nova interface possui pequenas **dicas** para opções que podem ser confusas.
- O **novo design da Tabela de Ações** torna muito mais claro como adicionar e remover Ações, algo que confundia muitas pessoas. Também encolhe e cresce para se ajustar ao número de Ações então você não precisa redimensioná-la manualmente.
- A nova **Aba Sobre** possui um layout bonito e coloca opções adicionais para suporte, feedback e mais ao seu alcance.
- Alguns **textos existentes da interface** foram melhorados.
- Agora há uma **nova opção** para Travar o Ponteiro do Mouse durante Gestos de Clique e Arraste. Não tenho um para testar, mas isso deve ser muito bom para Mouses Trackball!

## 8. Monetização

O Mac Mouse Fix 3 será **gratuito por 30 dias** e depois custará **$1.99** para ter.

Sei que pagar por algo que costumava ser gratuito não é a melhor sensação, mas espero poder convencê-lo de que é uma coisa realmente **boa para o projeto**!

Como para todos os outros aspectos do Mac Mouse Fix, prestei muita atenção em tornar a **experiência do usuário** o mais **simples** e **agradável** possível:

1. Os **30 dias gratuitos** são implementados de forma inteligente. O Mac Mouse Fix **só conta os dias** em que você **realmente o usa**. Então não há **pressão** para usar o app antes que o tempo acabe, e você pode tomar uma decisão informada se quer comprar o app ou não sem estresse.
2. Depois que os 30 dias gratuitos acabarem, **pagar** pelo app é extremamente **simples** e **rápido**. Você pode usar todos os métodos de pagamento que ama como **Apple Pay** e **PayPal**, e leva apenas **2 cliques** para pagar de dentro do app via Apple Pay!
3. Depois de comprar o app por $1.99, **ativar sua licença** também é extremamente **simples**. Na verdade, coloquei um **link** na **tela de checkout** no navegador web que te leva **diretamente** para o app e abre a **tela para inserir a licença** para você!
4. Depois que você **ativa sua licença**, há uma mensagem de agradecimento aleatória fofa na aba sobre. (Ouvi dizer que existem até algumas super secretas raras...)
5. Sua licença é **sincronizada via iCloud** então estará automaticamente disponível em todos os seus computadores!

Ajudando o Mac Mouse Fix financeiramente, você também pode me ajudar a **passar muito mais tempo** nele e torná-lo o **melhor driver de mouse DE TODOS**. 
Eu também _amo_ passar tempo no Mac Mouse Fix, então isso também me deixaria **feliz** :)

**O Mac Mouse Fix ainda será Código Aberto?**

Sim. O Mac Mouse Fix ainda será código aberto, e não planejo mudar isso em nenhum momento.

Isso também significa que você *pode* usar o Mac Mouse Fix gratuitamente compilando-o a partir do código fonte e desativando as verificações de licença. Isso é perfeitamente ok, eu só desencorajo compartilhar essas versões crackeadas online.
E claro, na próxima atualização, você receberá uma versão não-crackeada o que significa que terá que fazer isso novamente para cada atualização. (Ou apenas pagar $1.99 pelo melhor driver de mouse de todos! :)

Qualquer pessoa também ainda poderá usar o código fonte do Mac Mouse Fix em seus produtos gratuitos e comerciais desde que não vendam apenas uma cópia do Mac Mouse Fix sem adicionar sua própria contribuição.

Saiba mais sobre os detalhes na nova [Licença MMF](https://github.com/noah-nuebling/mac-mouse-fix/blob/version-3/LICENSE) sob a qual o MMF 3 será licenciado.

**Terei que pagar para usar o Beta do Mac Mouse Fix 3?**

Não. Você pode simplesmente usar seus 30 dias gratuitos. O contador de dias gratuitos provavelmente não será reiniciado quando a versão estável do Mac Mouse Fix 3 for lançada, já que isso seria algo extra para projetar e implementar e não acho que alguém se importará muito. (Me avise se você se importar). Mas vou estender o número de dias gratuitos se o beta durar mais de 30 dias.

**Posso obter o Mac Mouse Fix gratuitamente se já fiz uma doação?**

Sim! Se você me comprou um milkshake antes de 10 de setembro de 2022, você pode escrever um email para noah.n.public@gmail.com com "Milkshake Karma" no assunto e uma captura de tela como prova e então eu te enviarei um código de desconto de 100% ou algo assim!

## 9. Internacionalização

Com a reescrita da interface, agora é possível **traduzir** o Mac Mouse Fix para diferentes idiomas!

Já o traduzi para **Alemão**, meu idioma nativo, e você pode traduzi-lo para **seu idioma** também!

Planejo escrever um **guia mais detalhado** sobre isso no futuro, mas se você quiser tentar, aqui está uma pequena visão geral dos **passos**:

- **Baixe** o código fonte & Xcode
- **[Adicione seu idioma](https://developer.apple.com/documentation/xcode/adding-support-for-languages-and-regions)** ao projeto
- Coloque suas traduções nos arquivos **`.strings`** e **`.stringsdict`** por todo o projeto
- **Faça commit** de suas alterações e crie um **pull request**

Se sua tradução for adicionada ao projeto você receberá **10 cópias do MMF gratuitamente**, e claro, será **creditado como contribuidor**. Ouvi dizer que você também pode deixar sua **mensagem pessoal** alterando algumas das (mensagens secretas raras de agradecimento) na aba Sobre.

Talvez eu adicione **mais benefícios** no futuro. Me avise se você tiver alguma **ideia** para isso!

## 10. Como Você Pode Ajudar

Você pode ajudar compartilhando suas **ideias**, **problemas** e **feedback**!

O melhor lugar para compartilhar suas **ideias** e **problemas** é o [Assistente de Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
O melhor lugar para dar feedback **rápido** não estruturado é a [Discussão de Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Você também pode acessar ambos esses lugares de dentro do app na aba "**ⓘ Sobre**".

**Obrigado** por ajudar a tornar o Mac Mouse Fix melhor! 🚀