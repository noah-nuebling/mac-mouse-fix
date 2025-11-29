Mac Mouse Fix **3.0.6** torna a funcionalidade 'Retroceder' e 'Avançar' compatível com mais aplicações.
Também resolve vários bugs e problemas.

### Funcionalidade 'Retroceder' e 'Avançar' Melhorada

Os mapeamentos dos botões do rato 'Retroceder' e 'Avançar' agora **funcionam em mais aplicações**, incluindo:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed e outros editores de código
- Muitas aplicações nativas da Apple como Pré-visualização, Notas, Definições do Sistema, App Store e Música
- Adobe Acrobat
- Zotero
- E mais!

A implementação é inspirada na excelente funcionalidade 'Universal Back and Forward' do [LinearMouse](https://github.com/linearmouse/linearmouse). Deve suportar todas as aplicações que o LinearMouse suporta. \
Além disso, suporta algumas aplicações que normalmente requerem atalhos de teclado para retroceder e avançar, como Definições do Sistema, App Store, Apple Notes e Adobe Acrobat. O Mac Mouse Fix irá agora detetar essas aplicações e simular os atalhos de teclado apropriados.

Todas as aplicações que já foram [solicitadas numa GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) devem agora estar suportadas! (Obrigado pelo feedback!) \
Se encontrares alguma aplicação que ainda não funciona, avisa-me através de um [pedido de funcionalidade](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Resolução do Bug 'O Scroll Para de Funcionar Intermitentemente'

Alguns utilizadores experienciaram um [problema](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) em que o **scroll suave para de funcionar** aleatoriamente.

Embora nunca tenha conseguido reproduzir o problema, implementei uma potencial correção:

A aplicação irá agora tentar várias vezes quando a configuração da sincronização com o ecrã falhar. \
Se ainda não funcionar após as tentativas, a aplicação irá:

- Reiniciar o processo em segundo plano 'Mac Mouse Fix Helper', o que pode resolver o problema
- Produzir um relatório de falha, que pode ajudar a diagnosticar o bug

Espero que o problema esteja agora resolvido! Caso contrário, avisa-me através de um [relatório de bug](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) ou por [email](http://redirect.macmousefix.com/?target=mailto-noah).



### Comportamento Melhorado da Roda de Scroll de Rotação Livre

O Mac Mouse Fix **deixará de acelerar o scroll** quando deixas a roda de scroll girar livremente no rato MX Master. (Ou qualquer outro rato com uma roda de scroll de rotação livre.)

Embora esta funcionalidade de 'aceleração de scroll' seja útil em rodas de scroll normais, numa roda de scroll de rotação livre pode tornar as coisas mais difíceis de controlar.

**Nota:** O Mac Mouse Fix atualmente não é totalmente compatível com a maioria dos ratos Logitech, incluindo o MX Master. Planeio adicionar suporte completo, mas provavelmente vai demorar algum tempo. Entretanto, o melhor driver de terceiros com suporte Logitech que conheço é o [SteerMouse](https://plentycom.jp/en/steermouse/).





### Correções de Bugs

- Corrigido um problema em que o Mac Mouse Fix por vezes reativava atalhos de teclado que tinham sido previamente desativados nas Definições do Sistema  
- Corrigida uma falha ao clicar em 'Ativar Licença' 
- Corrigida uma falha ao clicar em 'Cancelar' logo após clicar em 'Ativar Licença' (Obrigado pelo relatório, Ali!)
- Corrigidas falhas ao tentar usar o Mac Mouse Fix sem nenhum ecrã ligado ao teu Mac 
- Corrigida uma fuga de memória e alguns outros problemas internos ao alternar entre separadores na aplicação 

### Melhorias Visuais

- Corrigido um problema em que o separador Acerca de era por vezes demasiado alto, que foi introduzido na versão [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- O texto na notificação 'Os dias grátis terminaram' já não é cortado em chinês
- Corrigida uma falha visual na sombra do campo '+' após gravar uma entrada
- Corrigida uma falha rara em que o texto de marcador de posição no ecrã 'Introduz a Tua Chave de Licença' aparecia descentrado
- Corrigido um problema em que alguns símbolos exibidos na aplicação tinham a cor errada após alternar entre modo escuro/claro

### Outras Melhorias

- Tornadas algumas animações, como a animação de mudança de separador, ligeiramente mais eficientes  
- Desativado o preenchimento automático de texto da Touch Bar no ecrã 'Introduz a Tua Chave de Licença' 
- Várias melhorias internas menores

*Editado com excelente assistência do Claude.*

---

Consulta também a versão anterior [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).