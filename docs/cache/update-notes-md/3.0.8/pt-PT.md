O Mac Mouse Fix **3.0.8** resolve problemas de interface e muito mais.

### **Problemas de Interface**

- Desativado o novo design no macOS 26 Tahoe. Agora a aplicação terá o aspeto e funcionará como no macOS 15 Sequoia.
    - Fiz isto porque alguns dos elementos de interface redesenhados pela Apple ainda têm problemas. Por exemplo, os botões '-' no separador 'Botões' nem sempre eram clicáveis.
    - A interface pode parecer um pouco desatualizada no macOS 26 Tahoe agora. Mas deverá estar totalmente funcional e polida como antes.
- Corrigido um erro em que a notificação 'Os dias gratuitos terminaram' ficava presa no canto superior direito do ecrã.
    - Obrigado ao [Sashpuri](https://github.com/Sashpuri) e outros por reportarem!

### **Melhorias de Interface**

- Desativado o botão de semáforo verde na janela principal do Mac Mouse Fix.
    - O botão não fazia nada, uma vez que a janela não pode ser redimensionada manualmente.
- Corrigido um problema em que algumas das linhas horizontais na tabela do separador 'Botões' estavam demasiado escuras no macOS 26 Tahoe.
- Corrigido um erro em que a mensagem "O botão principal do rato não pode ser usado" no separador 'Botões' era por vezes cortada no macOS 26 Tahoe.
- Corrigido um erro de digitação na interface alemã. Cortesia do utilizador do GitHub [i-am-the-slime](https://github.com/i-am-the-slime). Obrigado!
- Resolvido um problema em que a janela do MMF por vezes piscava brevemente com o tamanho errado ao abrir a janela no macOS 26 Tahoe.

### **Outras Alterações**

- Melhorado o comportamento ao tentar ativar o Mac Mouse Fix enquanto várias instâncias do Mac Mouse Fix estão a ser executadas no computador.
    - O Mac Mouse Fix tentará agora desativar a outra instância do Mac Mouse Fix de forma mais diligente.
    - Isto pode melhorar casos extremos em que o Mac Mouse Fix não podia ser ativado.
- Alterações e limpeza internas.

---

Vê também as novidades da versão anterior [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).