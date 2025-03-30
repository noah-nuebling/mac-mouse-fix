**ℹ️ Nota para Utilizadores do Mac Mouse Fix 2**

Com a introdução do Mac Mouse Fix 3, o modelo de preços da aplicação mudou:

- **Mac Mouse Fix 2**\
Continua 100% gratuito, e planeio continuar a dar-lhe suporte.\
**Ignore esta atualização** para continuar a usar o Mac Mouse Fix 2. Descarregue a última versão do Mac Mouse Fix 2 [aqui](https://redirect.macmousefix.com/?target=mmf2-latest).
- **Mac Mouse Fix 3**\
Gratuito durante 30 dias, custa alguns euros para ter.\
**Atualize agora** para obter o Mac Mouse Fix 3!

Pode saber mais sobre os preços e funcionalidades do Mac Mouse Fix 3 no [novo website](https://macmousefix.com/).

Obrigado por usar o Mac Mouse Fix! :)

---

**ℹ️ Nota para Compradores do Mac Mouse Fix 3**

Se atualizou acidentalmente para o Mac Mouse Fix 3 sem saber que já não é gratuito, gostaria de oferecer um [reembolso](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

A última versão do Mac Mouse Fix 2 continua **totalmente gratuita**, e pode descarregá-la [aqui](https://redirect.macmousefix.com/?target=mmf2-latest).

Peço desculpa pelo incómodo, e espero que todos fiquem satisfeitos com esta solução!

---

O Mac Mouse Fix **3.0.3** está pronto para o macOS 15 Sequoia. Também corrige alguns problemas de estabilidade e oferece várias pequenas melhorias.

### Suporte para macOS 15 Sequoia

A aplicação agora funciona corretamente no macOS 15 Sequoia!

- A maioria das animações da interface estavam quebradas no macOS 15 Sequoia. Agora tudo funciona corretamente de novo!
- O código fonte agora pode ser compilado no macOS 15 Sequoia. Antes, havia problemas com o compilador Swift que impediam a compilação da aplicação.

### Resolução de crashes durante a rolagem

Desde o Mac Mouse Fix 3.0.2 houve [vários relatos](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) do Mac Mouse Fix desativar-se e reativar-se periodicamente durante a rolagem. Isto era causado por crashes da aplicação de fundo 'Mac Mouse Fix Helper'. Esta atualização tenta corrigir estes crashes, com as seguintes alterações:

- O mecanismo de rolagem tentará recuperar e continuar a funcionar em vez de crashar, quando encontrar o caso específico que parece ter levado a estes crashes.
- Mudei a forma como os estados inesperados são tratados na aplicação de forma mais geral: Em vez de crashar imediatamente, a aplicação agora tentará recuperar de estados inesperados em muitos casos.

    - Esta mudança contribui para as correções dos crashes de rolagem descritos acima. Também pode prevenir outros crashes.

Nota: Nunca consegui reproduzir estes crashes na minha máquina, e ainda não tenho certeza do que os causou, mas com base nos relatos que recebi, esta atualização deve prevenir quaisquer crashes. Se ainda experienciar crashes durante a rolagem ou se experienciou crashes na versão 3.0.2, seria valioso se partilhasse a sua experiência e dados de diagnóstico no Issue do GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Isto ajudaria-me a entender o problema e melhorar o Mac Mouse Fix. Obrigado!

### Resolução de travamentos durante a rolagem

Na versão 3.0.2 fiz alterações na forma como o Mac Mouse Fix envia eventos de rolagem para o sistema numa tentativa de reduzir travamentos provavelmente causados por problemas com as APIs VSync da Apple.

No entanto, após testes mais extensivos e feedback, parece que o novo mecanismo na versão 3.0.2 torna a rolagem mais suave em alguns cenários mas mais travada em outros. Especialmente no Firefox, parecia estar notavelmente pior.\
No geral, não ficou claro que o novo mecanismo realmente melhorou os travamentos de rolagem em todos os casos. Além disso, pode ter contribuído para os crashes de rolagem descritos acima.

Por isso, desativei o novo mecanismo e voltei o mecanismo VSync para eventos de rolagem ao que era no Mac Mouse Fix 3.0.0 e 3.0.1.

Veja o Issue do GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) para mais informações.

### Reembolso

Peço desculpa pelos problemas relacionados com as alterações de rolagem nas versões 3.0.1 e 3.0.2. Subestimei vastamente os problemas que viriam com isso, e fui lento a resolver estes problemas. Farei o meu melhor para aprender com esta experiência e ser mais cuidadoso com tais alterações no futuro. Também gostaria de oferecer um reembolso a qualquer pessoa afetada. Basta clicar [aqui](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) se estiver interessado.

### Mecanismo de atualização mais inteligente

Estas alterações foram trazidas do Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) e [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consulte as suas notas de lançamento para saber mais sobre os detalhes. Aqui está um resumo:

- Há um novo mecanismo mais inteligente que decide qual atualização mostrar ao utilizador.
- Mudança do framework de atualização Sparkle 1.26.0 para o mais recente Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- A janela que a aplicação mostra para informar que uma nova versão do Mac Mouse Fix está disponível agora suporta JavaScript, o que permite uma formatação mais agradável das notas de atualização.

### Outras Melhorias e Correções de Bugs

- Corrigido um problema onde o preço da aplicação e informações relacionadas eram exibidos incorretamente no separador 'Sobre' em alguns casos.
- Corrigido um problema onde o mecanismo para sincronizar a rolagem suave com a taxa de atualização do ecrã não funcionava corretamente ao usar vários monitores.
- Várias pequenas limpezas e melhorias internas.

---

Veja também o lançamento anterior [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).