Mac Mouse Fix **3.0.1** traz várias correções de bugs e melhorias, junto com um **novo idioma**!

### Vietnamita foi adicionado!

Mac Mouse Fix agora está disponível em 🇻🇳 Vietnamita. Muito obrigado ao @nghlt [no GitHub](https://GitHub.com/nghlt)!

### Correções de bugs

- Mac Mouse Fix agora funciona corretamente com a **Troca Rápida de Usuário**!
  - Troca Rápida de Usuário é quando você faz login em uma segunda conta do macOS sem fazer logout da primeira conta.
  - Antes desta atualização, a rolagem parava de funcionar após uma troca rápida de usuário. Agora tudo deve funcionar corretamente.
- Corrigido um pequeno bug onde o layout da aba Botões ficava muito largo após iniciar o Mac Mouse Fix pela primeira vez.
- O campo '+' agora funciona de forma mais confiável ao adicionar várias Ações em sucessão rápida.
- Corrigido um crash obscuro reportado por @V-Coba no Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Outras melhorias

- **A rolagem está mais responsiva** ao usar a configuração 'Suavidade: Regular'.
  - A velocidade da animação agora fica mais rápida conforme você move a roda de rolagem mais rapidamente. Dessa forma, fica mais responsivo quando você rola rápido enquanto mantém a mesma suavidade quando você rola devagar.

- A **aceleração da velocidade de rolagem** está mais estável e previsível.
- Implementado um mecanismo para **manter suas configurações** quando você atualiza para uma nova versão do Mac Mouse Fix.
  - Antes, o Mac Mouse Fix resetava todas as suas configurações após atualizar para uma nova versão, se a estrutura das configurações mudasse. Agora, o Mac Mouse Fix tentará atualizar a estrutura das suas configurações e manter suas preferências.
  - Por enquanto, isso só funciona ao atualizar da versão 3.0.0 para 3.0.1. Se você estiver atualizando de uma versão anterior à 3.0.0, ou se você _fizer downgrade_ da 3.0.1 _para_ uma versão anterior, suas configurações ainda serão resetadas.
- O layout da aba Botões agora adapta melhor sua largura para diferentes idiomas.
- Melhorias no [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) e outros documentos.
- Sistemas de localização aprimorados. Os arquivos de tradução agora são automaticamente limpos e analisados para possíveis problemas. Há um novo [Guia de Localização](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) que apresenta quaisquer problemas detectados automaticamente junto com outras informações úteis e instruções para pessoas que querem ajudar a traduzir o Mac Mouse Fix. Removida a dependência da ferramenta [BartyCrouch](https://github.com/FlineDev/BartyCrouch) que era anteriormente usada para obter parte dessa funcionalidade.
- Melhoradas várias strings da interface em inglês e alemão.
- Muitas melhorias e limpezas nos bastidores.

---

Confira também as notas de lançamento do [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - a maior atualização do Mac Mouse Fix até agora!