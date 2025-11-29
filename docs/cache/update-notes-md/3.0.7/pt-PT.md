O Mac Mouse Fix **3.0.7** corrige vários bugs importantes.

### Correções de Bugs

- A aplicação volta a funcionar em **versões mais antigas do macOS** (macOS 10.15 Catalina e macOS 11 Big Sur) 
    - O Mac Mouse Fix 3.0.6 não podia ser ativado nessas versões do macOS porque a funcionalidade melhorada de 'Retroceder' e 'Avançar' introduzida no Mac Mouse Fix 3.0.6 tentava usar APIs do sistema macOS que não estavam disponíveis.
- Corrigidos problemas com a funcionalidade de **'Retroceder' e 'Avançar'**
    - A funcionalidade melhorada de 'Retroceder' e 'Avançar' introduzida no Mac Mouse Fix 3.0.6 irá agora usar sempre a 'thread principal' para perguntar ao macOS quais teclas simular para retroceder e avançar na aplicação que estás a usar. \
    Isto pode prevenir crashes e comportamento pouco fiável em algumas situações.
- Tentativa de corrigir o bug onde as **definições eram reiniciadas aleatoriamente**  (Vê estas [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Reescrevi o código que carrega o ficheiro de configuração do Mac Mouse Fix para ser mais robusto. Quando ocorriam erros raros do sistema de ficheiros do macOS, o código antigo podia por vezes pensar erradamente que o ficheiro de configuração estava corrompido e reiniciá-lo para as predefinições.
- Reduzidas as hipóteses de um bug onde o **scroll deixa de funcionar**     
     - Este bug não pode ser totalmente resolvido sem alterações mais profundas, que provavelmente causariam outros problemas. \
      No entanto, por enquanto, reduzi a janela de tempo onde pode acontecer um 'deadlock' no sistema de scroll, o que deve pelo menos diminuir as hipóteses de encontrar este bug. Isto também torna o scroll ligeiramente mais eficiente. 
    - Este bug tem sintomas semelhantes – mas penso que uma razão subjacente diferente – ao bug 'Scroll Deixa de Funcionar Intermitentemente' que foi abordado no último lançamento 3.0.6.
    - (Obrigado ao Joonas pelo diagnóstico!) 

Obrigado a todos por reportarem os bugs! 

---

Vê também o lançamento anterior [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).