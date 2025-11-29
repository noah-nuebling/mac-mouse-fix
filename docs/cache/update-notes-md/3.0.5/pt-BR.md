Mac Mouse Fix **3.0.5** corrige vários bugs, melhora o desempenho e adiciona um pouco de polimento ao app. \
Também é compatível com macOS 26 Tahoe.

### Simulação Aprimorada de Rolagem do Trackpad

- O sistema de rolagem agora pode simular um toque com dois dedos no trackpad para fazer os aplicativos pararem de rolar.
    - Isso corrige um problema ao executar apps de iPhone ou iPad, onde a rolagem frequentemente continuava após o usuário escolher parar.
- Corrigida a simulação inconsistente de levantar os dedos do trackpad.
    - Isso pode ter causado comportamento não ideal em algumas situações.



### Compatibilidade com macOS 26 Tahoe

Ao executar o Beta do macOS 26 Tahoe, o app agora é utilizável e a maior parte da interface funciona corretamente.



### Melhoria de Desempenho

Melhorado o desempenho do gesto de Clicar e Arrastar para "Rolar e Navegar". \
Nos meus testes, o uso de CPU foi reduzido em ~50%!

**Contexto**

Durante o gesto "Rolar e Navegar", o Mac Mouse Fix desenha um cursor de mouse falso em uma janela transparente, enquanto trava o cursor de mouse real no lugar. Isso garante que você possa continuar rolando o elemento da interface em que começou a rolar, não importa o quão longe você mova seu mouse.

A melhoria de desempenho foi alcançada desativando o tratamento padrão de eventos do macOS nesta janela transparente, que não estava sendo usado de qualquer forma.





### Correções de Bugs

- Agora ignorando eventos de rolagem de tablets de desenho Wacom.
    - Antes, o Mac Mouse Fix estava causando rolagem errática em tablets Wacom, conforme relatado por @frenchie1980 no GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Obrigado!)
    
- Corrigido um bug onde o código Swift Concurrency, que foi introduzido como parte do novo sistema de licenciamento no Mac Mouse Fix 3.0.4, não executava na thread correta.
    - Isso causava crashes no macOS Tahoe, e também provavelmente causava outros bugs esporádicos relacionados ao licenciamento.
- Melhorada a robustez do código que decodifica licenças offline.
    - Isso contorna um problema nas APIs da Apple que fazia a validação de licença offline sempre falhar no meu Mac Mini Intel. Presumo que isso acontecia em todos os Macs Intel, e que foi a razão pela qual o bug "Dias gratuitos acabaram" (que já foi abordado na versão 3.0.4) ainda ocorria para algumas pessoas, conforme relatado por @toni20k5267 no GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Obrigado!)
        - Se você experimentou o bug "Dias gratuitos acabaram", me desculpe por isso! Você pode obter um reembolso [aqui](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Melhorias de UX

- Desativados os diálogos que forneciam soluções passo a passo para bugs do macOS que impediam os usuários de habilitar o Mac Mouse Fix.
    - Esses problemas ocorriam apenas no macOS 13 Ventura e 14 Sonoma. Agora, esses diálogos aparecem apenas nas versões do macOS onde são relevantes. 
    - Os diálogos também são um pouco mais difíceis de acionar – antes, às vezes apareciam em situações onde não eram muito úteis.
    
- Adicionado um link "Ativar Licença" diretamente na notificação "Dias gratuitos acabaram". 
    - Isso torna a ativação de uma licença do Mac Mouse Fix ainda mais prática!

### Melhorias Visuais

- Ligeiramente melhorada a aparência da janela "Atualização de Software". Agora ela se encaixa melhor com o macOS 26 Tahoe. 
    - Isso foi feito personalizando a aparência padrão do framework "Sparkle 1.27.3" que o Mac Mouse Fix usa para gerenciar atualizações.
- Corrigido problema onde o texto na parte inferior da aba Sobre às vezes era cortado em chinês, tornando a janela um pouco mais larga.
- Corrigido o texto na parte inferior da aba Sobre que estava ligeiramente desalinhado.
- Corrigido um bug que fazia o espaço sob a opção "Atalho de Teclado..." na aba Botões ser muito pequeno. 

### Mudanças Internas

- Removida a dependência do framework "SnapKit".
    - Isso reduz ligeiramente o tamanho do app de 19,8 para 19,5 MB.
- Várias outras pequenas melhorias no código.

*Editado com excelente assistência do Claude.*

---

Confira também a versão anterior [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).