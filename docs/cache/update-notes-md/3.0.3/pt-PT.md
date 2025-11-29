Mac Mouse Fix **3.0.3** está pronto para o macOS 15 Sequoia. Também corrige alguns problemas de estabilidade e fornece várias pequenas melhorias.

### Suporte para macOS 15 Sequoia

A aplicação agora funciona corretamente no macOS 15 Sequoia!

- A maioria das animações da interface estava com problemas no macOS 15 Sequoia. Agora está tudo a funcionar corretamente novamente!
- O código-fonte agora pode ser compilado no macOS 15 Sequoia. Antes, havia problemas com o compilador Swift que impediam a compilação da aplicação.

### Resolução de falhas no scroll

Desde o Mac Mouse Fix 3.0.2 houve [vários relatos](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) de que o Mac Mouse Fix se desativava e reativava periodicamente durante o scroll. Isto era causado por falhas da aplicação em segundo plano 'Mac Mouse Fix Helper'. Esta atualização tenta corrigir estas falhas, com as seguintes alterações:

- O mecanismo de scroll tentará recuperar e continuar a funcionar em vez de falhar, quando encontrar o caso extremo que parece ter levado a estas falhas.
- Alterei a forma como estados inesperados são tratados na aplicação de forma mais geral: Em vez de falhar sempre imediatamente, a aplicação tentará agora recuperar de estados inesperados em muitos casos.
    
    - Esta alteração contribui para as correções das falhas de scroll descritas acima. Também pode prevenir outras falhas.
  
Nota: Nunca consegui reproduzir estas falhas na minha máquina, e ainda não tenho a certeza do que as causou, mas com base nos relatos que recebi, esta atualização deverá prevenir quaisquer falhas. Se ainda tiveres falhas durante o scroll ou se *tiveste* falhas na versão 3.0.2, seria valioso se partilhasses a tua experiência e dados de diagnóstico no GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Isto ajudar-me-ia a compreender o problema e a melhorar o Mac Mouse Fix. Obrigado!

### Resolução de engasgos no scroll

Na versão 3.0.2 fiz alterações à forma como o Mac Mouse Fix envia eventos de scroll ao sistema numa tentativa de reduzir engasgos no scroll provavelmente causados por problemas com as APIs VSync da Apple.

No entanto, após testes mais extensivos e feedback, parece que o novo mecanismo na versão 3.0.2 torna o scroll mais suave em alguns cenários mas mais irregular noutros. Especialmente no Firefox parecia ser visivelmente pior. \
No geral, não ficou claro que o novo mecanismo realmente melhorou os engasgos no scroll de forma generalizada. Além disso, pode ter contribuído para as falhas de scroll descritas acima.

Por isso desativei o novo mecanismo e revertei o mecanismo VSync para eventos de scroll de volta a como estava no Mac Mouse Fix 3.0.0 e 3.0.1.

Consulta o GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) para mais informações.

### Reembolso

Peço desculpa pelos problemas relacionados com as alterações de scroll nas versões 3.0.1 e 3.0.2. Subestimei vastamente os problemas que viriam com isso, e fui lento a resolver estas questões. Farei o meu melhor para aprender com esta experiência e ser mais cuidadoso com tais alterações no futuro. Gostaria também de oferecer um reembolso a qualquer pessoa afetada. Basta clicar [aqui](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) se estiveres interessado.

### Mecanismo de atualização mais inteligente

Estas alterações foram trazidas do Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) e [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consulta as notas de lançamento para saberes mais sobre os detalhes. Aqui está um resumo:

- Há um novo mecanismo mais inteligente que decide qual atualização mostrar ao utilizador.
- Mudámos de usar o framework de atualização Sparkle 1.26.0 para o Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3) mais recente.
- A janela que a aplicação exibe para te informar que uma nova versão do Mac Mouse Fix está disponível agora suporta JavaScript, o que permite uma formatação mais agradável das notas de atualização.

### Outras Melhorias e Correções de Bugs

- Corrigido um problema em que o preço da aplicação e informações relacionadas eram exibidos incorretamente no separador 'Acerca' em alguns casos.
- Corrigido um problema em que o mecanismo para sincronizar o scroll suave com a taxa de atualização do ecrã não funcionava corretamente ao usar vários ecrãs.
- Muitas pequenas limpezas e melhorias internas.

---

Consulta também o lançamento anterior [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).