Mac Mouse Fix **2.2.1** oferece **suporte completo para macOS Ventura** entre outras alterações.

### Suporte para Ventura!
Mac Mouse Fix agora suporta totalmente e funciona de forma nativa no macOS 13 Ventura.
Agradecimentos especiais a [@chamburr](https://github.com/chamburr) que ajudou com o suporte para Ventura no Issue do GitHub [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Alterações incluem:

- Interface atualizada para conceder Acesso de Acessibilidade refletindo as novas Definições do Sistema do Ventura
- Mac Mouse Fix será exibido corretamente no novo menu **Definições do Sistema > Itens de Login** do Ventura
- Mac Mouse Fix reagirá adequadamente quando desativado em **Definições do Sistema > Itens de Login**

### Descontinuado suporte para versões antigas do macOS

Infelizmente, a Apple só permite desenvolver _para_ macOS 10.13 **High Sierra e posterior** quando se desenvolve _a partir do_ macOS 13 Ventura.

Assim, a **versão mínima suportada** aumentou do 10.11 El Capitan para 10.13 High Sierra.

### Correções de bugs

- Corrigido um problema onde o Mac Mouse Fix alterava o comportamento de scroll de algumas **mesas digitalizadoras**. Ver Issue do GitHub [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Corrigido um problema onde **atalhos de teclado** incluindo a tecla 'A' não podiam ser gravados. Corrige o Issue do GitHub [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Corrigido um problema onde alguns **remapeamentos de botões** não funcionavam corretamente ao usar um layout de teclado não padrão.
- Corrigido um crash nas '**Definições específicas por app**' ao tentar adicionar uma app sem 'Bundle ID'. Pode ajudar com o Issue do GitHub [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Corrigido um crash ao tentar adicionar apps sem nome às '**Definições específicas por app**'. Resolve o Issue do GitHub [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Agradecimentos especiais a [jeongtae](https://github.com/jeongtae) que foi muito prestável em descobrir o problema!
- Mais pequenas correções de bugs e melhorias internas.