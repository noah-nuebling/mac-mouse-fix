Mac Mouse Fix **2.2.1** oferece **suporte completo para macOS Ventura** entre outras mudanças.

### Suporte ao Ventura!
Mac Mouse Fix agora oferece suporte total e se integra nativamente ao macOS 13 Ventura.
Agradecimentos especiais ao [@chamburr](https://github.com/chamburr) que ajudou com o suporte ao Ventura na Issue do GitHub [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Mudanças incluem:

- Interface atualizada para concessão de Acesso à Acessibilidade refletindo as novas Configurações do Sistema do Ventura
- Mac Mouse Fix será exibido corretamente no novo menu **Configurações do Sistema > Itens de Login** do Ventura
- Mac Mouse Fix reagirá adequadamente quando for desativado em **Configurações do Sistema > Itens de Login**

### Descontinuação do suporte para versões antigas do macOS

Infelizmente, a Apple só permite desenvolver _para_ macOS 10.13 **High Sierra e posterior** quando desenvolvendo _a partir do_ macOS 13 Ventura.

Então a **versão mínima suportada** aumentou do 10.11 El Capitan para 10.13 High Sierra.

### Correções de bugs

- Corrigido um problema onde o Mac Mouse Fix alterava o comportamento de rolagem de algumas **mesas digitalizadoras**. Veja a Issue do GitHub [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Corrigido um problema onde **atalhos de teclado** incluindo a tecla 'A' não podiam ser gravados. Corrige a Issue do GitHub [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Corrigido um problema onde alguns **remapeamentos de botões** não funcionavam corretamente ao usar um layout de teclado não padrão.
- Corrigido um crash nas '**Configurações específicas por app**' ao tentar adicionar um app sem 'Bundle ID'. Pode ajudar com a Issue do GitHub [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Corrigido um crash ao tentar adicionar apps sem nome às '**Configurações específicas por app**'. Resolve a Issue do GitHub [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Agradecimentos especiais ao [jeongtae](https://github.com/jeongtae) que foi muito prestativo em descobrir o problema!
- Mais pequenas correções de bugs e melhorias internas.