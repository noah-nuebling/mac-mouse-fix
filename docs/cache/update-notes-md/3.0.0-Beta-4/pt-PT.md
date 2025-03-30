Confira também **o que há de novo** em [3.0.0 Beta 3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-3)!

---

**3.0.0 Beta 4** traz uma nova opção de **"Restaurar predefinições..."** bem como muitas melhorias na **qualidade de vida** e **correções de bugs**!

Aqui está **tudo** o que há de **novo**:

## 1. Opção "Restaurar Predefinições..."

Agora há um botão "**Restaurar Predefinições...**" no separador "Botões". 
Isto permite que te sintas ainda mais **confortável** ao **experimentar** as configurações.

Existem **2 predefinições** disponíveis:

1. A "Predefinição para ratos com **5+ botões**" é super poderosa e confortável. Na verdade, permite-te fazer **tudo** o que fazes num **trackpad**. Tudo usando os 2 **botões laterais** que estão exatamente onde o teu **polegar** repousa! Mas claro que só está disponível em ratos com 5 ou mais botões.
2. A "Predefinição para ratos com **3 botões**" ainda te permite fazer as **coisas mais importantes** que fazes num trackpad - mesmo num rato que só tem 3 botões.

Esforcei-me para tornar esta funcionalidade **inteligente**:

- Quando inicias o MMF pela primeira vez, ele irá **selecionar automaticamente** a predefinição que **melhor se adapta ao teu rato**.
- Quando fores restaurar as predefinições, o Mac Mouse Fix irá **mostrar-te** qual o **modelo do rato** que estás a usar e o seu **número de botões**, para que possas facilmente escolher qual das duas predefinições usar. Também irá **pré-selecionar** a predefinição que **melhor se adapta ao teu rato**.
- Quando mudares para um **novo rato** que não se adapta às tuas configurações atuais, um popup no separador Botões irá **lembrar-te** como **carregar** as configurações recomendadas para o teu rato!
- Toda a **interface** em torno disto é muito **simples**, **bonita** e **anima** de forma agradável.

Espero que aches esta funcionalidade **útil** e **simples de usar**! Mas avisa-me se tiveres algum problema.
Algo está **estranho** ou **pouco intuitivo**? Os **popups** aparecem **demasiadas vezes** ou em **situações inapropriadas**? **Diz-me** a tua experiência!

## 2. Mac Mouse Fix temporariamente gratuito em alguns países

Existem alguns **países** onde o **fornecedor de pagamentos** do Mac Mouse Fix, o Gumroad, **não funciona** atualmente.
O Mac Mouse Fix agora é **gratuito** nesses **países** até eu poder fornecer um método de pagamento alternativo!

Se estiveres num dos países gratuitos, informações sobre isto serão **exibidas** no **separador Sobre** e ao **inserir uma chave de licença**

Se for **impossível comprar** o Mac Mouse Fix no teu país, mas também **não é gratuito** no teu país ainda - avisa-me e tornarei o Mac Mouse Fix gratuito no teu país também!

## 3. Um bom momento para começar a traduzir!

Com o Beta 4, **implementei todas as alterações na interface** que planeei para o Mac Mouse Fix 3. Portanto, espero que não haja mais grandes alterações na interface até o lançamento do Mac Mouse Fix 3.

Se estavas a aguardar porque esperavas que a interface ainda mudasse, então **este é um bom momento** para começar a **traduzir** a aplicação para o teu idioma!

Para **mais informações** sobre a tradução da aplicação, consulta **[Notas de Lançamento do 3.0.0 Beta 1](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-1.1) > 9. Internacionalização**

## 4. Tudo o resto

Além das alterações listadas acima, o Beta 4 inclui muitas mais **correções de bugs**, **ajustes** e melhorias na **qualidade de vida**:

### Interface

#### Correções de bugs

- Corrigido bug onde links do separador Sobre abriam repetidamente ao clicar em qualquer lugar na janela. Créditos ao utilizador do GitHub [DingoBits](https://github.com/DingoBits) que corrigiu isto!
- Corrigido alguns símbolos na aplicação que não eram exibidos corretamente em versões mais antigas do macOS
- Ocultadas barras de rolagem na Tabela de Ações. Obrigado ao utilizador do GitHub [marianmelinte93](https://github.com/marianmelinte93) que me alertou sobre este problema neste [comentário](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366#discussioncomment-3728994)!
- Corrigido problema onde o feedback sobre funcionalidades sendo reativadas automaticamente quando abres o respetivo separador para essa funcionalidade na interface (depois de teres desativado essa respetiva funcionalidade da barra de menu) não era exibido no macOS Monterey e anteriores. Obrigado novamente ao [marianmelinte93](https://github.com/marianmelinte93) por me alertar sobre o problema.
- Adicionada localização em falta e traduções alemãs para a opção "Clicar para Rolar para Mover Entre Espaços"
- Corrigidos mais pequenos problemas de localização
- Adicionadas mais traduções alemãs em falta
- Notificações que aparecem quando um botão é capturado / não está mais capturado agora funcionam corretamente quando alguns botões foram capturados e outros foram descapturados ao mesmo tempo.

#### Melhorias

- Removida opção "Clicar e Rolar para Alternador de Aplicações". Era um pouco bugada e não acho que fosse muito útil.
- Adicionada opção "Clicar e Rolar para Rodar".
- Ajustado layout do menu "Mac Mouse Fix" na barra de menu.
- Adicionado botão "Comprar Mac Mouse Fix" ao menu "Mac Mouse Fix" na barra de menu.
- Adicionado texto de dica abaixo da opção "Mostrar na Barra de Menu". O objetivo é tornar mais descobrível que o item da barra de menu pode ser usado para rapidamente ligar ou desligar funcionalidades
- As mensagens "Obrigado por comprar o Mac Mouse Fix" no ecrã sobre agora podem ser totalmente personalizadas pelos localizadores.
- Melhoradas dicas para localizadores
- Melhorados textos da interface sobre expiração do período de teste
- Melhorados textos da interface no separador Sobre
- Adicionados destaques em negrito a alguns textos da interface para melhorar a legibilidade
- Adicionado alerta ao clicar no link "Enviar-me um Email" no separador Sobre.
- Alterada ordem de classificação da Tabela de Ações. Ações de Clicar e Rolar agora aparecem antes das ações de Clicar e Arrastar. Isto parece mais natural para mim porque as linhas da tabela agora estão ordenadas por quão poderosos são seus gatilhos (Clicar < Rolar < Arrastar).
- A aplicação agora atualiza o dispositivo ativamente usado ao interagir com a interface. Isto é útil porque parte da interface agora é baseada no dispositivo que estás a usar. (Vê a nova funcionalidade "Restaurar predefinições...")
- Uma notificação que mostra quais botões foram capturados / não estão mais capturados agora aparece quando inicias a aplicação pela primeira vez.
- Mais melhorias nas notificações que aparecem quando um botão foi capturado / não está mais capturado
- Tornado impossível inserir acidentalmente espaços em branco extras ao ativar uma chave de licença

### Rato

#### Correções de bugs

- Melhorada simulação de rolagem para enviar corretamente "deltas de ponto fixo". Isto resolve um problema onde a velocidade de rolagem estava muito lenta em algumas aplicações como Safari com rolagem suave desativada.
- Corrigido problema onde a funcionalidade "Clicar e Arrastar para Mission Control & Espaços" ficava presa às vezes quando o computador estava lento
- Corrigido um problema onde a CPU era sempre usada pelo Mac Mouse Fix ao mover o rato depois de ter usado a funcionalidade "Clicar e Arrastar para Rolar & Navegar"

#### Melhorias

- Melhorada significativamente a responsividade do zoom de rolagem em navegadores baseados em Chromium como Chrome, Brave ou Edge

### Sob o capô

#### Correções de bugs

- Corrigido um problema onde o Mac Mouse Fix não funcionava corretamente após movê-lo para uma pasta diferente enquanto estava ativado
- Corrigidos alguns problemas com a ativação do Mac Mouse Fix enquanto outra instância do Mac Mouse Fix ainda estava ativada. (Isto é porque a Apple me permitiu mudar o ID do pacote de "com.nuebling.mac-mouse-fixxx" que era usado no Beta 3 de volta para o original "com.nuebling.mac-mouse-fix". Não sei porquê.)

#### Melhorias

- Este e futuros betas irão produzir informações de depuração mais detalhadas
- Limpeza e melhorias sob o capô. Removido código antigo pré-10.13. Limpos frameworks e dependências. O código-fonte agora é mais fácil de trabalhar, mais à prova de futuro.