O Mac Mouse Fix **2.2.5** traz melhorias no mecanismo de atualização e está pronto para o macOS 15 Sequoia!

### Novo framework de atualização Sparkle

O Mac Mouse Fix usa o framework de atualização [Sparkle](https://sparkle-project.org/) para ajudar a fornecer uma ótima experiência de atualização.

Com o 2.2.5, o Mac Mouse Fix muda do Sparkle 1.26.0 para o mais recente Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), contendo correções de segurança, melhorias de localização e mais.

### Mecanismo de atualização mais inteligente

Há um novo mecanismo que decide qual atualização mostrar ao usuário. O comportamento mudou das seguintes formas:

1. Depois de pular uma atualização **principal** (como 2.2.5 -> 3.0.0), você ainda será notificado sobre novas atualizações **menores** (como 2.2.5 -> 2.2.6).
    - Isso permite que você permaneça facilmente no Mac Mouse Fix 2 enquanto ainda recebe atualizações, como discutido na Issue do GitHub [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Em vez de mostrar a atualização para a versão mais recente, o Mac Mouse Fix agora mostrará a atualização para a primeira versão da última versão principal.
    - Exemplo: Se você estiver usando o MMF 2.2.5, e o MMF 3.4.5 for a versão mais recente, o app agora mostrará a primeira versão do MMF 3 (3.0.0), em vez da versão mais recente (3.4.5). Dessa forma, todos os usuários do MMF 2.2.5 veem o changelog do MMF 3.0.0 antes de mudar para o MMF 3.
    - Discussão:
        - A principal motivação por trás disso é que, no início deste ano, muitos usuários do MMF 2 atualizaram diretamente do MMF 2 para o MMF 3.0.1 ou 3.0.2. Como nunca viram o changelog do 3.0.0, perderam qualquer informação sobre as mudanças de preço entre o MMF 2 e o MMF 3 (MMF 3 não sendo mais 100% gratuito). Então, quando o MMF 3 de repente dizia que eles precisavam pagar para continuar usando o app, alguns ficaram - compreensivelmente - um pouco confusos e chateados.
        - Desvantagem: Se você quiser apenas atualizar para a versão mais recente, agora terá que atualizar duas vezes em alguns casos. Isso é um pouco ineficiente, mas ainda deve levar apenas alguns segundos. E como isso torna as mudanças entre versões principais muito mais transparentes, acho que é uma troca sensata.

### Suporte ao macOS 15 Sequoia

O Mac Mouse Fix 2.2.5 funcionará perfeitamente no novo macOS 15 Sequoia - assim como o 2.2.4 funcionou.

---

Confira também a versão anterior [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Se você tiver problemas para ativar o Mac Mouse Fix após a atualização, consulte o ['Guia de Ativação do Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*