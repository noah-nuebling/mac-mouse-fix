**ℹ️ Nota para Usuários do Mac Mouse Fix 2**

Com a introdução do Mac Mouse Fix 3, o modelo de preços do app mudou:

- **Mac Mouse Fix 2**\
Continua 100% gratuito, e pretendo continuar dando suporte.\
**Pule esta atualização** para continuar usando o Mac Mouse Fix 2. Baixe a última versão do Mac Mouse Fix 2 [aqui](https://redirect.macmousefix.com/?target=mmf2-latest).
- **Mac Mouse Fix 3**\
Gratuito por 30 dias, custa alguns dólares para ter.\
**Atualize agora** para obter o Mac Mouse Fix 3!

Você pode saber mais sobre os preços e recursos do Mac Mouse Fix 3 no [novo site](https://macmousefix.com/).

Obrigado por usar o Mac Mouse Fix! :)

---

**ℹ️ Nota para Compradores do Mac Mouse Fix 3**

Se você atualizou acidentalmente para o Mac Mouse Fix 3 sem saber que ele não é mais gratuito, gostaria de oferecer um [reembolso](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

A última versão do Mac Mouse Fix 2 continua **totalmente gratuita**, e você pode baixá-la [aqui](https://redirect.macmousefix.com/?target=mmf2-latest).

Desculpe pelo transtorno, e espero que todos fiquem satisfeitos com esta solução!

---

Mac Mouse Fix **3.0.3** está pronto para o macOS 15 Sequoia. Também corrige alguns problemas de estabilidade e traz várias pequenas melhorias.

### Suporte ao macOS 15 Sequoia

O app agora funciona corretamente no macOS 15 Sequoia!

- A maioria das animações da interface estava quebrada no macOS 15 Sequoia. Agora tudo está funcionando corretamente novamente!
- O código-fonte agora pode ser compilado no macOS 15 Sequoia. Antes, havia problemas com o compilador Swift impedindo a compilação do app.

### Resolvendo crashes de rolagem

Desde o Mac Mouse Fix 3.0.2, houve [vários relatos](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) do Mac Mouse Fix se desativando e reativando periodicamente durante a rolagem. Isso era causado por crashes do app em segundo plano 'Mac Mouse Fix Helper'. Esta atualização tenta corrigir esses crashes com as seguintes mudanças:

- O mecanismo de rolagem tentará se recuperar e continuar funcionando em vez de travar quando encontrar o caso específico que parece ter levado a esses crashes.
- Mudei a forma como estados inesperados são tratados no app de modo geral: Em vez de sempre travar imediatamente, o app agora tentará se recuperar de estados inesperados em muitos casos.

    - Esta mudança contribui para as correções dos crashes de rolagem descritos acima. Também pode prevenir outros crashes.

Observação: Nunca consegui reproduzir esses crashes na minha máquina e ainda não tenho certeza do que os causou, mas com base nos relatos que recebi, esta atualização deve prevenir quaisquer crashes. Se você ainda experimentar crashes durante a rolagem ou se você experimentou crashes na versão 3.0.2, seria valioso se você compartilhasse sua experiência e dados de diagnóstico na Issue do GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Isso me ajudaria a entender o problema e melhorar o Mac Mouse Fix. Obrigado!

### Resolvendo travamentos na rolagem

Na versão 3.0.2, fiz mudanças na forma como o Mac Mouse Fix envia eventos de rolagem para o sistema, numa tentativa de reduzir travamentos provavelmente causados por problemas com as APIs VSync da Apple.

No entanto, após testes mais extensivos e feedback, parece que o novo mecanismo na versão 3.0.2 torna a rolagem mais suave em alguns cenários, mas mais travada em outros. Especialmente no Firefox, parecia estar notavelmente pior.\
No geral, não ficou claro se o novo mecanismo realmente melhorou os travamentos de rolagem em todos os casos. Além disso, pode ter contribuído para os crashes de rolagem descritos acima.

Por isso, desativei o novo mecanismo e voltei o mecanismo VSync para eventos de rolagem ao que era no Mac Mouse Fix 3.0.0 e 3.0.1.

Veja a Issue do GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) para mais informações.

### Reembolso

Peço desculpas pelos problemas relacionados às mudanças de rolagem nas versões 3.0.1 e 3.0.2. Subestimei enormemente os problemas que viriam com isso, e demorei para resolver essas questões. Farei o possível para aprender com essa experiência e ser mais cuidadoso com tais mudanças no futuro. Também gostaria de oferecer reembolso a qualquer pessoa afetada. Basta clicar [aqui](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) se estiver interessado.

### Mecanismo de atualização mais inteligente

Essas mudanças foram trazidas do Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) e [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Confira suas notas de lançamento para saber mais sobre os detalhes. Aqui está um resumo:

- Há um novo mecanismo mais inteligente que decide qual atualização mostrar ao usuário.
- Mudança do framework de atualização Sparkle 1.26.0 para o mais recente Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- A janela que o app exibe para informar que uma nova versão do Mac Mouse Fix está disponível agora suporta JavaScript, o que permite uma formatação mais agradável das notas de atualização.

### Outras Melhorias e Correções de Bugs

- Corrigido um problema onde o preço do app e informações relacionadas eram exibidos incorretamente na aba 'Sobre' em alguns casos.
- Corrigido um problema onde o mecanismo para sincronizar a rolagem suave com a taxa de atualização da tela não funcionava corretamente ao usar múltiplos monitores.
- Várias pequenas melhorias e limpezas internas.

---

Confira também o lançamento anterior [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).