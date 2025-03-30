O Mac Mouse Fix **2.2.5** apresenta melhorias no mecanismo de atualização e está pronto para o macOS 15 Sequoia!

### Nova estrutura de atualização Sparkle

O Mac Mouse Fix utiliza a estrutura de atualização [Sparkle](https://sparkle-project.org/) para ajudar a proporcionar uma excelente experiência de atualização.

Com o 2.2.5, o Mac Mouse Fix muda do Sparkle 1.26.0 para o mais recente Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), que contém correções de segurança, melhorias de localização e mais.

### Mecanismo de atualização mais inteligente

Existe um novo mecanismo que decide qual atualização mostrar ao utilizador. O comportamento mudou das seguintes formas:

1. Depois de ignorar uma atualização **major** (como 2.2.5 -> 3.0.0), continuarás a ser notificado de novas atualizações **minor** (como 2.2.5 -> 2.2.6).
    - Isto permite-te manter facilmente o Mac Mouse Fix 2 enquanto continuas a receber atualizações, como discutido no Issue do GitHub [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Em vez de mostrar a atualização para a versão mais recente, o Mac Mouse Fix irá agora mostrar-te a atualização para a primeira versão da última versão major.
    - Exemplo: Se estiveres a usar o MMF 2.2.5, e o MMF 3.4.5 for a versão mais recente, a app irá agora mostrar-te a primeira versão do MMF 3 (3.0.0), em vez da versão mais recente (3.4.5). Desta forma, todos os utilizadores do MMF 2.2.5 veem o changelog do MMF 3.0.0 antes de mudarem para o MMF 3.
    - Discussão:
        - A principal motivação por detrás disto é que, no início deste ano, muitos utilizadores do MMF 2 atualizaram diretamente do MMF 2 para o MMF 3.0.1 ou 3.0.2. Como nunca viram o changelog do 3.0.0, perderam qualquer informação sobre as alterações de preços entre o MMF 2 e o MMF 3 (o MMF 3 já não é 100% gratuito). Então, quando o MMF 3 disse de repente que precisavam de pagar para continuar a usar a app, alguns ficaram - compreensivelmente - um pouco confusos e chateados.
        - Desvantagem: Se quiseres apenas atualizar para a versão mais recente, agora terás de atualizar duas vezes em alguns casos. Isto é ligeiramente ineficiente, mas ainda deve demorar apenas alguns segundos. E como isto torna as mudanças entre versões major muito mais transparentes, penso que é um compromisso sensato.

### Suporte para macOS 15 Sequoia

O Mac Mouse Fix 2.2.5 funcionará muito bem no novo macOS 15 Sequoia - tal como o 2.2.4 funcionou.

---

Confere também a versão anterior [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Se tiveres problemas para ativar o Mac Mouse Fix após a atualização, consulta o ['Guia de Ativação do Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*