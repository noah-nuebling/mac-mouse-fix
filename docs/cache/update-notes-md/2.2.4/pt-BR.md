Mac Mouse Fix **2.2.4** agora está notarizado! Também inclui algumas pequenas correções de bugs e outras melhorias.

### **Notarização**

Mac Mouse Fix 2.2.4 agora está 'notarizado' pela Apple. Isso significa que não haverá mais mensagens sobre o Mac Mouse Fix ser potencialmente um 'Software Malicioso' ao abrir o aplicativo pela primeira vez.

#### Contexto

Notarizar seu aplicativo custa $100 por ano. Eu sempre fui contra isso, pois parecia hostil com software livre e de código aberto como o Mac Mouse Fix, e também parecia um passo perigoso em direção à Apple controlar e restringir o Mac como fazem com iPhones ou iPads. Mas a falta de notarização levou a diferentes problemas, incluindo [dificuldades para abrir o aplicativo](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) e até [várias situações](https://github.com/noah-nuebling/mac-mouse-fix/issues/95) onde ninguém conseguia usar o aplicativo até que eu lançasse uma nova versão.

Para o Mac Mouse Fix 3, achei que finalmente era apropriado pagar os $100 por ano para notarizar o aplicativo, já que o Mac Mouse Fix 3 é monetizado. ([Saiba Mais](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Agora, o Mac Mouse Fix 2 também recebe notarização, o que deve levar a uma experiência do usuário mais fácil e estável.

### **Correções de bugs**

- Corrigido um problema onde o cursor desaparecia e depois reaparecia em um local diferente ao usar uma Ação de 'Clicar e Arrastar' durante uma gravação de tela ou ao usar o software [DisplayLink](https://www.synaptics.com/products/displaylink-graphics).
- Corrigido um problema com a ativação do Mac Mouse Fix no macOS 10.14 Mojave e possivelmente em versões mais antigas do macOS também.
- Melhorado o gerenciamento de memória, potencialmente corrigindo uma falha do aplicativo 'Mac Mouse Fix Helper', que ocorria ao desconectar um mouse do computador. Veja a Discussão [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Outras Melhorias**

- A janela que o aplicativo exibe para informar que uma nova versão do Mac Mouse Fix está disponível agora suporta JavaScript. Isso permite que as notas de atualização fiquem mais bonitas e mais fáceis de ler. Por exemplo, as notas de atualização agora podem exibir [Alertas em Markdown](https://github.com/orgs/community/discussions/16925) e mais.
- Removido um link para a página https://macmousefix.com/about/ da tela "Conceder Acesso de Acessibilidade ao Mac Mouse Fix Helper". Isso porque a página Sobre não existe mais e foi substituída pelo [README do GitHub](https://github.com/noah-nuebling/mac-mouse-fix) por enquanto.
- Esta versão agora inclui arquivos dSYM que podem ser usados por qualquer pessoa para decodificar relatórios de falha do Mac Mouse Fix 2.2.4.
- Algumas limpezas e melhorias internas.

---

Confira também a versão anterior [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).