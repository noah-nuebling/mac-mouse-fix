Confira também as **novidades** introduzidas no [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

Mac Mouse Fix **2.2.0** apresenta várias melhorias de usabilidade e correções de bugs!

### O remapeamento para teclas de função exclusivas da Apple está melhor agora

A última atualização, 2.1.0, introduziu um novo recurso interessante que permite remapear os botões do seu rato para qualquer tecla do teclado - mesmo teclas de função que só existem em teclados Apple. O 2.2.0 apresenta mais melhorias e refinamentos nesse recurso:

- Agora podes manter pressionada a tecla Option (⌥) para remapear para teclas que só existem em teclados Apple - mesmo que não tenhas um teclado Apple à mão.
- Os símbolos das teclas de função têm uma aparência melhorada, integrando-se melhor com outro texto.
- A capacidade de remapear para Caps Lock foi desativada. Não funcionava como esperado.

### Adiciona / remove Ações mais facilmente

Alguns utilizadores tiveram dificuldade em perceber que podem adicionar e remover Ações da Tabela de Ações. Para tornar as coisas mais fáceis de entender, o 2.2.0 apresenta as seguintes alterações e novos recursos:

- Agora podes eliminar Ações clicando com o botão direito nelas.
  - Isto deve tornar mais fácil descobrir a opção de eliminar Ações.
  - O menu do botão direito apresenta um símbolo do botão '-'. Isto deve ajudar a chamar a atenção para o _botão_ '-', que por sua vez deve chamar a atenção para o botão '+'. Isto esperamos que torne a opção de **adicionar** Ações mais fácil de descobrir também.
- Agora podes adicionar Ações à Tabela de Ações clicando com o botão direito numa linha vazia.
- O botão '-' agora só está ativo quando uma Ação está selecionada. Isto deve tornar mais claro que o botão '-' elimina a Ação selecionada.
- A altura padrão da janela foi aumentada para que haja uma linha vazia visível que pode ser clicada com o botão direito para adicionar uma Ação.
- Os botões '+' e '-' agora têm dicas de ferramentas.

### Melhorias no Clique e Arrasto

O limite para ativar o Clique e Arrasto foi aumentado de 5 pixels para 7 pixels. Isto torna mais difícil ativar acidentalmente o Clique e Arrasto, permitindo ainda aos utilizadores mudar de Spaces, etc., usando movimentos pequenos e confortáveis.

### Outras alterações na interface

- A aparência da Tabela de Ações foi melhorada.
- Várias outras melhorias na interface.

### Correções de bugs

- Corrigido um problema em que a interface não ficava acinzentada ao iniciar o MMF enquanto estava desativado.
- Removida a opção oculta "Clique e Arrasto do Botão 3".
  - Ao selecioná-la, a aplicação crashava. Construí esta opção para tornar o Mac Mouse Fix mais compatível com o Blender. Mas na sua forma atual, não é muito útil para utilizadores do Blender porque não podes combiná-la com modificadores de teclado. Planeio melhorar a compatibilidade com o Blender numa versão futura.