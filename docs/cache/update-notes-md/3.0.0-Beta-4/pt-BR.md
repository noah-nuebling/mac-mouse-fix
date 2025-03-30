Confira também **o que há de novo** no [3.0.0 Beta 3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-3)!

---

**3.0.0 Beta 4** traz uma nova **opção "Restaurar padrões..."** além de várias **melhorias na qualidade de vida** e **correções de bugs**!

Aqui está **tudo** que há de **novo**:

## 1. Opção "Restaurar Padrões..."

Agora há um botão "**Restaurar Padrões...**" na aba "Botões".
Isso permite que você se sinta ainda mais **confortável** ao **experimentar** as configurações.

Existem **2 padrões** disponíveis:

1. A "Configuração padrão para mouses com **5+ botões**" é super poderosa e confortável. Na verdade, permite que você faça **tudo** que faz no **trackpad**. Tudo usando os 2 **botões laterais** que ficam exatamente onde seu **polegar** descansa! Mas é claro que só está disponível em mouses com 5 ou mais botões.
2. A "Configuração padrão para mouses com **3 botões**" ainda permite fazer as **coisas mais importantes** que você faz no trackpad - mesmo em um mouse que só tem 3 botões.

Me esforcei para tornar este recurso **inteligente**:

- Quando você iniciar o MMF pela primeira vez, ele **selecionará automaticamente** a predefinição que **melhor se adapta ao seu mouse**.
- Quando você for restaurar os padrões, o Mac Mouse Fix **mostrará** qual **modelo de mouse** você está usando e seu **número de botões**, para que você possa escolher facilmente qual das duas predefinições usar. Ele também **pré-selecionará** a predefinição que **melhor se adapta ao seu mouse**.
- Quando você mudar para um **novo mouse** que não se encaixa nas suas configurações atuais, um popup na aba Botões **lembrará** como **carregar** as configurações recomendadas para seu mouse!
- Toda a **interface** em torno disso é muito **simples**, **bonita** e **anima** suavemente.

Espero que você ache este recurso **útil** e **fácil de usar**! Mas me avise se tiver algum problema.
Algo está **estranho** ou **não intuitivo**? Os **popups** aparecem **muito frequentemente** ou em **situações inapropriadas**? **Me conte** sobre sua experiência!

## 2. Mac Mouse Fix temporariamente gratuito em alguns países

Existem alguns **países** onde o **provedor de pagamento** do Mac Mouse Fix, o Gumroad, **não funciona** atualmente.
O Mac Mouse Fix agora é **gratuito** nesses **países** até que eu possa fornecer um método de pagamento alternativo!

Se você estiver em um dos países gratuitos, informações sobre isso serão **exibidas** na **aba Sobre** e ao **inserir uma chave de licença**

Se for **impossível comprar** o Mac Mouse Fix no seu país, mas também **não estiver gratuito** no seu país ainda - me avise e tornarei o Mac Mouse Fix gratuito no seu país também!

## 3. Um bom momento para começar a traduzir!

Com o Beta 4, **implementei todas as mudanças na interface** que planejei para o Mac Mouse Fix 3. Então, espero que não haja mais grandes mudanças na interface até o lançamento do Mac Mouse Fix 3.

Se você estava esperando porque achava que a interface ainda mudaria, então **este é um bom momento** para começar a **traduzir** o app para seu idioma!

Para **mais informações** sobre a tradução do app, veja **[Notas de Lançamento do 3.0.0 Beta 1](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-1.1) > 9. Internacionalização**

## 4. Todo o resto

Além das mudanças listadas acima, o Beta 4 apresenta muitas outras pequenas **correções de bugs**, **ajustes** e **melhorias na qualidade de vida**:

### Interface

#### Correções de bugs

- Corrigido bug onde links da aba Sobre abriam repetidamente ao clicar em qualquer lugar na janela. Créditos ao usuário do GitHub [DingoBits](https://github.com/DingoBits) que corrigiu isso!
- Corrigido alguns símbolos no app que não eram exibidos corretamente em versões mais antigas do macOS
- Ocultas barras de rolagem na Tabela de Ações. Obrigado ao usuário do GitHub [marianmelinte93](https://github.com/marianmelinte93) que me alertou sobre este problema neste [comentário](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366#discussioncomment-3728994)!
- Corrigido problema onde o feedback sobre recursos sendo reativados automaticamente quando você abre a respectiva aba para esse recurso na interface (depois de desabilitar esse respectivo recurso da barra de menu) não era exibido no macOS Monterey e anteriores. Obrigado novamente ao [marianmelinte93](https://github.com/marianmelinte93) por me alertar sobre o problema.
- Adicionada localização faltante e traduções em alemão para a opção "Clique para Rolar para Mover Entre Espaços"
- Corrigidos mais pequenos problemas de localização
- Adicionadas mais traduções em alemão faltantes
- Notificações que aparecem quando um botão é capturado / não está mais capturado agora funcionam corretamente quando alguns botões foram capturados e outros foram descapturados ao mesmo tempo.

#### Melhorias

- Removida opção "Clique e Role para Alternador de Apps". Era um pouco bugada e acho que não era muito útil.
- Adicionada opção "Clique e Role para Rotacionar".
- Ajustado layout do menu "Mac Mouse Fix" na barra de menu.
- Adicionado botão "Comprar Mac Mouse Fix" ao menu "Mac Mouse Fix" na barra de menu.
- Adicionado texto de dica abaixo da opção "Mostrar na Barra de Menu". O objetivo é tornar mais descobrível que o item da barra de menu pode ser usado para ativar ou desativar recursos rapidamente
- As mensagens "Obrigado por comprar o Mac Mouse Fix" na tela sobre agora podem ser totalmente personalizadas pelos localizadores.
- Melhoradas dicas para localizadores
- Melhorados textos da interface sobre expiração do teste
- Melhorados textos da interface na aba Sobre
- Adicionados destaques em negrito em alguns textos da interface para melhorar a legibilidade
- Adicionado alerta ao clicar no link "Me Envie um Email" na aba Sobre.
- Alterada ordem de classificação da Tabela de Ações. Ações de Clique e Rolagem agora serão exibidas antes das ações de Clique e Arrasto. Isso me parece mais natural porque as linhas da tabela agora estão ordenadas por quão poderosos são seus gatilhos (Clique < Rolagem < Arrasto).
- O app agora atualizará o dispositivo ativamente usado ao interagir com a interface. Isso é útil porque parte da interface agora é baseada no dispositivo que você está usando. (Veja o novo recurso "Restaurar padrões...")
- Uma notificação que mostra quais botões foram capturados / não estão mais capturados agora aparece quando você inicia o app pela primeira vez.
- Mais melhorias nas notificações que aparecem quando um botão foi capturado / não está mais capturado
- Tornado impossível inserir acidentalmente espaços em branco extras ao ativar uma chave de licença

### Mouse

#### Correções de bugs

- Melhorada simulação de rolagem para enviar corretamente "deltas de ponto fixo". Isso resolve um problema onde a velocidade de rolagem estava muito lenta em alguns apps como Safari com rolagem suave desativada.
- Corrigido problema onde o recurso "Clique e Arraste para Mission Control & Spaces" às vezes travava quando o computador estava lento
- Corrigido um problema onde a CPU era sempre usada pelo Mac Mouse Fix ao mover o mouse depois de ter usado o recurso "Clique e Arraste para Rolar & Navegar"

#### Melhorias

- Melhorada muito a responsividade do zoom de rolagem em navegadores baseados em Chromium como Chrome, Brave ou Edge

### Sob o capô

#### Correções de bugs

- Corrigido um problema onde o Mac Mouse Fix não funcionava corretamente após movê-lo para uma pasta diferente enquanto estava ativado
- Corrigidos alguns problemas com a ativação do Mac Mouse Fix enquanto outra instância do Mac Mouse Fix ainda estava ativada. (Isso é porque a Apple me permitiu mudar o ID do pacote de "com.nuebling.mac-mouse-fixxx" que era usado no Beta 3 de volta para o original "com.nuebling.mac-mouse-fix". Não sei por quê.)

#### Melhorias

- Este e futuros betas produzirão informações de depuração mais detalhadas
- Limpeza e melhorias sob o capô. Removido código antigo pré-10.13. Limpos frameworks e dependências. O código-fonte agora é mais fácil de trabalhar, mais à prova de futuro.