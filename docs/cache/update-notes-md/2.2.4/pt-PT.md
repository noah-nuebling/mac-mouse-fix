O Mac Mouse Fix **2.2.4** está agora notarizado! Também inclui algumas pequenas correções de bugs e outras melhorias.

### **Notarização**

O Mac Mouse Fix 2.2.4 está agora 'notarizado' pela Apple. Isso significa que não haverá mais mensagens sobre o Mac Mouse Fix ser potencialmente um 'Software Malicioso' ao abrir a aplicação pela primeira vez.

#### Contexto

Notarizar a sua aplicação custa $100 por ano. Sempre fui contra isto, pois parecia hostil para software gratuito e de código aberto como o Mac Mouse Fix, e também parecia um passo perigoso em direção à Apple controlar e bloquear o Mac como fazem com iPhones ou iPads. Mas a falta de notarização levou a diferentes problemas, incluindo [dificuldades para abrir a aplicação](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) e até [várias situações](https://github.com/noah-nuebling/mac-mouse-fix/issues/95) onde ninguém conseguia usar a aplicação até eu lançar uma nova versão.

Para o Mac Mouse Fix 3, achei que finalmente era apropriado pagar os $100 por ano para notarizar a aplicação, já que o Mac Mouse Fix 3 é monetizado. ([Saber Mais](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Agora, o Mac Mouse Fix 2 também recebe notarização, o que deve levar a uma experiência de utilizador mais fácil e estável.

### **Correções de bugs**

- Corrigido um problema onde o cursor desaparecia e depois reaparecia num local diferente ao usar uma Ação de 'Clicar e Arrastar' durante uma gravação de ecrã ou ao usar o software [DisplayLink](https://www.synaptics.com/products/displaylink-graphics).
- Corrigido um problema com a ativação do Mac Mouse Fix no macOS 10.14 Mojave e possivelmente versões mais antigas do macOS também.
- Melhorada a gestão de memória, potencialmente corrigindo uma falha da aplicação 'Mac Mouse Fix Helper', que ocorria ao desconectar um rato do computador. Ver Discussão [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Outras Melhorias**

- A janela que a aplicação exibe para informar sobre uma nova versão do Mac Mouse Fix agora suporta JavaScript. Isto permite que as notas de atualização sejam mais bonitas e fáceis de ler. Por exemplo, as notas de atualização agora podem exibir [Alertas Markdown](https://github.com/orgs/community/discussions/16925) e mais.
- Removido um link para a página https://macmousefix.com/about/ do ecrã "Conceder Acesso de Acessibilidade ao Mac Mouse Fix Helper". Isto porque a página Sobre já não existe e foi substituída pelo [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix) por enquanto.
- Esta versão agora inclui ficheiros dSYM que podem ser usados por qualquer pessoa para descodificar relatórios de falhas do Mac Mouse Fix 2.2.4.
- Algumas limpezas e melhorias internas.

---

Confira também a versão anterior [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).