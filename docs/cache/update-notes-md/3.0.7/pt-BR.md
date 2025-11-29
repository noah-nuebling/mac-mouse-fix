Mac Mouse Fix **3.0.7** corrige vários bugs importantes.

### Correções de Bugs

- O app funciona novamente em **versões mais antigas do macOS** (macOS 10.15 Catalina e macOS 11 Big Sur) 
    - O Mac Mouse Fix 3.0.6 não podia ser habilitado nessas versões do macOS porque o recurso aprimorado de 'Voltar' e 'Avançar' introduzido no Mac Mouse Fix 3.0.6 tentava usar APIs do sistema macOS que não estavam disponíveis.
- Corrigidos problemas com o recurso de **'Voltar' e 'Avançar'**
    - O recurso aprimorado de 'Voltar' e 'Avançar' introduzido no Mac Mouse Fix 3.0.6 agora sempre usará a 'thread principal' para perguntar ao macOS quais teclas simular para voltar e avançar no app que você está usando. \
    Isso pode prevenir crashes e comportamento não confiável em algumas situações.
- Tentativa de corrigir o bug onde as **configurações eram redefinidas aleatoriamente** (Veja essas [Issues no GitHub](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Reescrevi o código que carrega o arquivo de configuração do Mac Mouse Fix para ser mais robusto. Quando erros raros do sistema de arquivos do macOS ocorriam, o código antigo às vezes podia pensar erroneamente que o arquivo de configuração estava corrompido e redefini-lo para o padrão.
- Reduzidas as chances de um bug onde a **rolagem para de funcionar**     
     - Este bug não pode ser totalmente resolvido sem mudanças mais profundas, que provavelmente causariam outros problemas. \
      No entanto, por enquanto, reduzi a janela de tempo onde um 'deadlock' pode acontecer no sistema de rolagem, o que deve pelo menos diminuir as chances de encontrar este bug. Isso também torna a rolagem um pouco mais eficiente. 
    - Este bug tem sintomas similares – mas acredito que uma razão subjacente diferente – do bug 'Rolagem Para de Funcionar Intermitentemente' que foi abordado no último lançamento 3.0.6.
    - (Obrigado ao Joonas pelos diagnósticos!) 

Obrigado a todos por reportarem os bugs! 

---

Confira também o lançamento anterior [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).