Mac Mouse Fix **3.0.8** resolve problemas de interface e mais.

### **Problemas de Interface**

- Desabilitado o novo design no macOS 26 Tahoe. Agora o app terá a aparência e funcionará como no macOS 15 Sequoia. 
    - Fiz isso porque alguns dos elementos de interface redesenhados pela Apple ainda têm problemas. Por exemplo, os botões '-' na aba 'Botões' nem sempre eram clicáveis.
    - A interface pode parecer um pouco desatualizada no macOS 26 Tahoe agora. Mas deve estar totalmente funcional e polida como antes.
- Corrigido um bug onde a notificação 'Dias gratuitos acabaram' ficava presa no canto superior direito da tela.
    - Obrigado ao [Sashpuri](https://github.com/Sashpuri) e outros por reportarem!

### **Refinamentos de Interface**

- Desabilitado o botão verde de semáforo na janela principal do Mac Mouse Fix.
    - O botão não fazia nada, já que a janela não pode ser redimensionada manualmente.
- Corrigido um problema onde algumas das linhas horizontais na tabela da aba 'Botões' estavam muito escuras no macOS 26 Tahoe.
- Corrigido um bug onde a mensagem "Botão primário do mouse não pode ser usado" na aba 'Botões' às vezes era cortada no macOS 26 Tahoe.
- Corrigido um erro de digitação na interface em alemão. Cortesia do usuário do GitHub [i-am-the-slime](https://github.com/i-am-the-slime). Obrigado!
- Resolvido um problema onde a janela do MMF às vezes piscava brevemente no tamanho errado ao abrir a janela no macOS 26 Tahoe.

### **Outras Mudanças**

- Melhorado o comportamento ao tentar habilitar o Mac Mouse Fix enquanto múltiplas instâncias do Mac Mouse Fix estão rodando no computador. 
    - O Mac Mouse Fix agora tentará desabilitar a outra instância do Mac Mouse Fix com mais diligência. 
    - Isso pode melhorar casos extremos onde o Mac Mouse Fix não podia ser habilitado.
- Mudanças e limpeza nos bastidores.

---

Confira também as novidades da versão anterior [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).