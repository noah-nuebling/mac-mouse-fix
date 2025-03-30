Confere também as **alterações interessantes** introduzidas no [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

O **3.0.0 Beta 5** restaura a **compatibilidade** com alguns **ratos** no macOS 13 Ventura e **corrige a rolagem** em várias aplicações.
Também inclui várias outras pequenas correções e melhorias na qualidade de vida.

Aqui está **tudo o que há de novo**:

### Rato

- Corrigida a rolagem no Terminal e outras aplicações! Vê o Issue no GitHub [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Corrigida a incompatibilidade com alguns ratos no macOS 13 Ventura, abandonando o uso de APIs Apple não confiáveis em favor de hacks de baixo nível. Espero que isto não introduza novos problemas - avisa-me se acontecer! Agradecimentos especiais à Maria e ao utilizador do GitHub [samiulhsnt](https://github.com/samiulhsnt) por ajudarem a descobrir isto! Vê o Issue no GitHub [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) para mais informações.
- Não usará CPU ao clicar nos Botões 1 ou 2 do rato. Uso de CPU ligeiramente reduzido ao clicar noutros botões.
    - Esta é uma "Debug Build", por isso o uso de CPU pode ser cerca de 10 vezes maior ao clicar nos botões nesta beta vs a versão final
- A simulação de rolagem do trackpad usada para as funcionalidades "Rolagem Suave" e "Rolar & Navegar" do Mac Mouse Fix está agora ainda mais precisa. Isto pode levar a um melhor comportamento em algumas situações.

### Interface

- Correção automática de problemas com a concessão de Acesso à Acessibilidade após atualizar de uma versão mais antiga do Mac Mouse Fix. Adota as alterações descritas nas [Notas de Lançamento 2.2.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Adicionado um botão "Cancelar" no ecrã "Conceder Acesso à Acessibilidade"
- Corrigido um problema onde a configuração do Mac Mouse Fix não funcionava corretamente após instalar uma nova versão, porque a nova versão se conectava à versão antiga do "Mac Mouse Fix Helper". Agora, o Mac Mouse Fix não se conectará mais à versão antiga do "Mac Mouse Fix Helper" e desativará a versão antiga automaticamente quando apropriado.
- Fornecendo instruções ao utilizador sobre como corrigir um problema onde o Mac Mouse Fix não pode ser ativado corretamente devido a outra versão do Mac Mouse Fix estar presente no sistema. Este problema ocorre apenas no macOS Ventura.
- Comportamento e animações aprimorados no ecrã "Conceder Acesso à Acessibilidade"
- O Mac Mouse Fix será trazido para o primeiro plano quando for ativado. Isto melhora as interações da interface em algumas situações, como quando ativas o Mac Mouse Fix depois de ter sido desativado em Definições do Sistema > Geral > Itens de Login.
- Textos da interface melhorados no ecrã "Conceder Acesso à Acessibilidade"
- Textos da interface melhorados que aparecem ao tentar ativar o Mac Mouse Fix enquanto está desativado nas Definições do Sistema
- Corrigido um texto em alemão na interface

### Bastidores

- O número de compilação do "Mac Mouse Fix" e do "Mac Mouse Fix Helper" incorporado estão agora sincronizados. Isto é usado para evitar que o "Mac Mouse Fix" se conecte acidentalmente a versões antigas do "Mac Mouse Fix Helper".
- Corrigido problema onde alguns dados sobre a tua licença e período de teste às vezes eram exibidos incorretamente ao iniciar a aplicação pela primeira vez, removendo dados em cache da configuração inicial
- Muita limpeza na estrutura do projeto e código-fonte
- Mensagens de depuração melhoradas

---

### Como Podes Ajudar

Podes ajudar partilhando as tuas **ideias**, **problemas** e **feedback**!

O melhor lugar para partilhar as tuas **ideias** e **problemas** é o [Assistente de Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
O melhor lugar para dar feedback **rápido** e não estruturado é a [Discussão de Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Também podes aceder a estes lugares dentro da aplicação no separador "**ⓘ Sobre**".

**Obrigado** por ajudares a tornar o Mac Mouse Fix melhor! 💙💛❤️