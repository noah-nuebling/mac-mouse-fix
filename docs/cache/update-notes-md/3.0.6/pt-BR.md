Mac Mouse Fix **3.0.6** torna o recurso 'Voltar' e 'Avançar' compatível com mais aplicativos.
Também corrige vários bugs e problemas.

### Recurso 'Voltar' e 'Avançar' Aprimorado

Os mapeamentos dos botões do mouse 'Voltar' e 'Avançar' agora **funcionam em mais aplicativos**, incluindo:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed e outros editores de código
- Muitos aplicativos nativos da Apple como Visualização, Notas, Ajustes do Sistema, App Store e Música
- Adobe Acrobat
- Zotero
- E mais!

A implementação é inspirada no excelente recurso 'Universal Back and Forward' do [LinearMouse](https://github.com/linearmouse/linearmouse). Deve suportar todos os aplicativos que o LinearMouse suporta. \
Além disso, suporta alguns aplicativos que normalmente requerem atalhos de teclado para voltar e avançar, como Ajustes do Sistema, App Store, Notas da Apple e Adobe Acrobat. O Mac Mouse Fix agora detectará esses aplicativos e simulará os atalhos de teclado apropriados.

Todos os aplicativos que já foram [solicitados em uma Issue do GitHub](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) devem estar suportados agora! (Obrigado pelo feedback!) \
Se você encontrar algum aplicativo que ainda não funciona, me avise em uma [solicitação de recurso](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Corrigindo o Bug 'Rolagem Para de Funcionar Intermitentemente'

Alguns usuários experimentaram um [problema](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) onde a **rolagem suave para de funcionar** aleatoriamente.

Embora eu nunca tenha conseguido reproduzir o problema, implementei uma possível correção:

O aplicativo agora tentará várias vezes quando a configuração da sincronização com o display falhar. \
Se ainda não funcionar após as tentativas, o aplicativo irá:

- Reiniciar o processo em segundo plano 'Mac Mouse Fix Helper', o que pode resolver o problema
- Produzir um relatório de falha, que pode ajudar a diagnosticar o bug

Espero que o problema esteja resolvido agora! Caso contrário, me avise em um [relatório de bug](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) ou por [email](http://redirect.macmousefix.com/?target=mailto-noah).



### Comportamento Aprimorado da Roda de Rolagem de Giro Livre

O Mac Mouse Fix **não irá mais acelerar a rolagem** para você quando você deixar a roda de rolagem girar livremente no mouse MX Master. (Ou qualquer outro mouse com roda de rolagem de giro livre.)

Embora esse recurso de 'aceleração de rolagem' seja útil em rodas de rolagem normais, em uma roda de rolagem de giro livre pode tornar as coisas mais difíceis de controlar.

**Nota:** O Mac Mouse Fix atualmente não é totalmente compatível com a maioria dos mouses Logitech, incluindo o MX Master. Planejo adicionar suporte completo, mas provavelmente levará um tempo. Enquanto isso, o melhor driver de terceiros com suporte Logitech que conheço é o [SteerMouse](https://plentycom.jp/en/steermouse/).





### Correções de Bugs

- Corrigido um problema onde o Mac Mouse Fix às vezes reativava atalhos de teclado que foram previamente desabilitados nos Ajustes do Sistema  
- Corrigida uma falha ao clicar em 'Ativar Licença' 
- Corrigida uma falha ao clicar em 'Cancelar' logo após clicar em 'Ativar Licença' (Obrigado pelo relato, Ali!)
- Corrigidas falhas ao tentar usar o Mac Mouse Fix enquanto nenhum display está conectado ao seu Mac 
- Corrigido um vazamento de memória e alguns outros problemas internos ao alternar entre abas no aplicativo 

### Melhorias Visuais

- Corrigido um problema onde a aba Sobre às vezes ficava muito alta, que foi introduzido na versão [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- O texto na notificação 'Dias gratuitos acabaram' não é mais cortado em chinês
- Corrigida uma falha visual na sombra do campo '+' após gravar uma entrada
- Corrigida uma falha rara onde o texto de espaço reservado na tela 'Digite Sua Chave de Licença' aparecia descentralizado
- Corrigido um problema onde alguns símbolos exibidos no aplicativo tinham a cor errada após alternar entre modo escuro/claro

### Outras Melhorias

- Tornei algumas animações, como a animação de troca de abas, um pouco mais eficientes  
- Desabilitado o preenchimento automático de texto da Touch Bar na tela 'Digite Sua Chave de Licença' 
- Várias melhorias internas menores

*Editado com excelente assistência do Claude.*

---

Confira também a versão anterior [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).