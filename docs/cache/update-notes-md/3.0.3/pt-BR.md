Mac Mouse Fix **3.0.3** está pronto para o macOS 15 Sequoia. Ele também corrige alguns problemas de estabilidade e oferece várias pequenas melhorias.

### Suporte ao macOS 15 Sequoia

O app agora funciona corretamente no macOS 15 Sequoia!

- A maioria das animações da interface estava quebrada no macOS 15 Sequoia. Agora está tudo funcionando corretamente de novo!
- O código-fonte agora pode ser compilado no macOS 15 Sequoia. Antes, havia problemas com o compilador Swift que impediam a compilação do app.

### Resolvendo travamentos na rolagem

Desde o Mac Mouse Fix 3.0.2 houve [vários relatos](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) de que o Mac Mouse Fix estava se desativando e reativando periodicamente durante a rolagem. Isso foi causado por travamentos do app em segundo plano 'Mac Mouse Fix Helper'. Esta atualização tenta corrigir esses travamentos, com as seguintes mudanças:

- O mecanismo de rolagem tentará se recuperar e continuar funcionando em vez de travar, quando encontrar o caso extremo que parece ter levado a esses travamentos.
- Mudei a forma como estados inesperados são tratados no app de maneira mais geral: Em vez de sempre travar imediatamente, o app agora tentará se recuperar de estados inesperados em muitos casos.
    
    - Esta mudança contribui para as correções dos travamentos na rolagem descritos acima. Ela também pode prevenir outros travamentos.
  
Observação: Nunca consegui reproduzir esses travamentos na minha máquina, e ainda não tenho certeza do que os causou, mas com base nos relatos que recebi, esta atualização deve prevenir quaisquer travamentos. Se você ainda tiver travamentos durante a rolagem ou se você *teve* travamentos na versão 3.0.2, seria valioso se você compartilhasse sua experiência e dados de diagnóstico no GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Isso me ajudaria a entender o problema e melhorar o Mac Mouse Fix. Obrigado!

### Resolvendo engasgos na rolagem

Na versão 3.0.2 fiz mudanças na forma como o Mac Mouse Fix envia eventos de rolagem para o sistema numa tentativa de reduzir engasgos na rolagem provavelmente causados por problemas com as APIs VSync da Apple.

No entanto, após testes mais extensivos e feedback, parece que o novo mecanismo na 3.0.2 torna a rolagem mais suave em alguns cenários, mas mais engasgada em outros. Especialmente no Firefox parecia estar visivelmente pior. \
No geral, não ficou claro que o novo mecanismo realmente melhorou os engasgos na rolagem de forma geral. Além disso, ele pode ter contribuído para os travamentos na rolagem descritos acima.

Por isso desativei o novo mecanismo e reverter o mecanismo VSync para eventos de rolagem de volta para como estava no Mac Mouse Fix 3.0.0 e 3.0.1.

Veja o GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) para mais informações.

### Reembolso

Peço desculpas pelos problemas relacionados às mudanças na rolagem nas versões 3.0.1 e 3.0.2. Subestimei muito os problemas que viriam com isso, e fui lento para resolver essas questões. Farei o meu melhor para aprender com essa experiência e ser mais cuidadoso com essas mudanças no futuro. Também gostaria de oferecer um reembolso a qualquer pessoa afetada. Basta clicar [aqui](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) se tiver interesse.

### Mecanismo de atualização mais inteligente

Essas mudanças foram trazidas do Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) e [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Confira as notas de lançamento deles para saber mais sobre os detalhes. Aqui está um resumo:

- Há um novo mecanismo mais inteligente que decide qual atualização mostrar ao usuário.
- Mudamos do framework de atualização Sparkle 1.26.0 para o Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3) mais recente.
- A janela que o app exibe para informar que uma nova versão do Mac Mouse Fix está disponível agora suporta JavaScript, o que permite uma formatação mais bonita das notas de atualização.

### Outras Melhorias e Correções de Bugs

- Corrigido um problema onde o preço do app e informações relacionadas eram exibidos incorretamente na aba 'Sobre' em alguns casos.
- Corrigido um problema onde o mecanismo para sincronizar a rolagem suave com a taxa de atualização da tela não funcionava corretamente ao usar múltiplas telas.
- Muitas pequenas limpezas e melhorias internas.

---

Confira também o lançamento anterior [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).