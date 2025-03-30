Confira também as **novidades** introduzidas no [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

Mac Mouse Fix **2.2.0** traz várias melhorias de usabilidade e correções de bugs!

### Remapeamento para teclas de função exclusivas da Apple está melhor agora

A última atualização, 2.1.0, introduziu um novo recurso legal que permite remapear os botões do mouse para qualquer tecla do teclado - até mesmo teclas de função encontradas apenas em teclados Apple. O 2.2.0 traz mais melhorias e refinamentos para esse recurso:

- Agora você pode segurar Option (⌥) para remapear para teclas encontradas apenas em teclados Apple - mesmo que você não tenha um teclado Apple em mãos.
- Os símbolos das teclas de função têm uma aparência melhorada, harmonizando melhor com outros textos.
- A capacidade de remapear para Caps Lock foi desativada. Não funcionava como esperado.

### Adicione / remova Ações mais facilmente

Alguns usuários tiveram dificuldade em descobrir que é possível adicionar e remover Ações da Tabela de Ações. Para tornar as coisas mais fáceis de entender, o 2.2.0 traz as seguintes mudanças e novos recursos:

- Agora você pode excluir Ações clicando com o botão direito nelas.
  - Isso deve facilitar a descoberta da opção de excluir Ações.
  - O menu do botão direito apresenta um símbolo do botão '-'. Isso deve ajudar a chamar atenção para o _botão_ '-', que por sua vez deve chamar atenção para o botão '+'. Esperamos que isso torne a opção de **adicionar** Ações mais fácil de descobrir também.
- Agora você pode adicionar Ações à Tabela de Ações clicando com o botão direito em uma linha vazia.
- O botão '-' agora só fica ativo quando uma Ação está selecionada. Isso deve deixar mais claro que o botão '-' exclui a Ação selecionada.
- A altura padrão da janela foi aumentada para que haja uma linha vazia visível que pode ser clicada com o botão direito para adicionar uma Ação.
- Os botões '+' e '-' agora têm dicas de ferramentas.

### Melhorias no Clique e Arraste

O limite para ativar o Clique e Arraste foi aumentado de 5 pixels para 7 pixels. Isso torna mais difícil ativar acidentalmente o Clique e Arraste, mas ainda permite que os usuários alternem entre Spaces etc. usando movimentos pequenos e confortáveis.

### Outras mudanças na interface

- A aparência da Tabela de Ações foi melhorada.
- Várias outras melhorias na interface.

### Correções de bugs

- Corrigido um problema onde a interface não ficava acinzentada ao iniciar o MMF enquanto estava desativado.
- Removida a opção oculta "Botão 3 Clique e Arraste".
  - Ao selecioná-la, o aplicativo travava. Eu criei essa opção para tornar o Mac Mouse Fix mais compatível com o Blender. Mas em sua forma atual, não é muito útil para usuários do Blender porque você não pode combiná-la com modificadores de teclado. Planejo melhorar a compatibilidade com o Blender em uma versão futura.