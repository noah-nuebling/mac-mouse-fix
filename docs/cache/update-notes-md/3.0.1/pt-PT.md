Mac Mouse Fix **3.0.1** traz várias correções de bugs e melhorias, junto com um **novo idioma**!

### Vietnamita foi adicionado!

Mac Mouse Fix está agora disponível em 🇻🇳 Vietnamita. Muito obrigado ao @nghlt [no GitHub](https://GitHub.com/nghlt)!

### Correções de bugs

- Mac Mouse Fix agora funciona corretamente com a **Mudança Rápida de Utilizador**!
  - Mudança Rápida de Utilizador é quando inicias sessão numa segunda conta macOS sem terminar sessão na primeira conta.
  - Antes desta atualização, a rolagem deixava de funcionar após uma mudança rápida de utilizador. Agora tudo deve funcionar corretamente.
- Corrigido um pequeno bug onde o layout do separador Botões estava muito largo após iniciar o Mac Mouse Fix pela primeira vez.
- O campo '+' agora funciona de forma mais fiável ao adicionar várias Ações em sucessão rápida.
- Corrigido um crash obscuro reportado por @V-Coba no Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Outras melhorias

- **A rolagem está mais responsiva** quando se usa a configuração 'Suavidade: Regular'.
  - A velocidade da animação agora torna-se mais rápida à medida que moves a roda do rato mais rapidamente. Assim, sente-se mais responsivo quando fazes scroll rápido enquanto mantém a mesma suavidade quando fazes scroll lentamente.

- A **aceleração da velocidade de scroll** está mais estável e previsível.
- Implementado um mecanismo para **manter as tuas configurações** quando atualizas para uma nova versão do Mac Mouse Fix.
  - Antes, o Mac Mouse Fix reiniciava todas as tuas configurações após atualizar para uma nova versão, se a estrutura das configurações mudasse. Agora, o Mac Mouse Fix tentará atualizar a estrutura das tuas configurações e manter as tuas preferências.
  - Por enquanto, isto só funciona ao atualizar da versão 3.0.0 para 3.0.1. Se estiveres a atualizar de uma versão anterior à 3.0.0, ou se _voltares_ da 3.0.1 _para_ uma versão anterior, as tuas configurações ainda serão reiniciadas.
- O layout do separador Botões agora adapta melhor a sua largura a diferentes idiomas.
- Melhorias no [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) e outros documentos.
- Sistemas de localização melhorados. Os ficheiros de tradução são agora automaticamente limpos e analisados para potenciais problemas. Há um novo [Guia de Localização](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) que apresenta quaisquer problemas detetados automaticamente junto com outras informações úteis e instruções para pessoas que querem ajudar a traduzir o Mac Mouse Fix. Removida a dependência da ferramenta [BartyCrouch](https://github.com/FlineDev/BartyCrouch) que era anteriormente usada para obter parte desta funcionalidade.
- Melhoradas várias strings da UI em Inglês e Alemão.
- Muitas melhorias e limpezas nos bastidores.

---

Confere também as notas de lançamento do [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - a maior atualização do Mac Mouse Fix até agora!