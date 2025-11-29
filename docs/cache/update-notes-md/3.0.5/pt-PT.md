O Mac Mouse Fix **3.0.5** corrige vários bugs, melhora o desempenho e adiciona um pouco de polimento à aplicação. \
Também é compatível com o macOS 26 Tahoe.

### Simulação Melhorada do Deslocamento do Trackpad

- O sistema de deslocamento pode agora simular um toque com dois dedos no trackpad para fazer as aplicações pararem de se deslocar.
    - Isto corrige um problema ao executar aplicações de iPhone ou iPad, onde o deslocamento muitas vezes continuava após o utilizador escolher parar.
- Corrigida a simulação inconsistente de levantar os dedos do trackpad.
    - Isto pode ter causado comportamento subótimo em algumas situações.



### Compatibilidade com macOS 26 Tahoe

Ao executar a versão Beta do macOS 26 Tahoe, a aplicação é agora utilizável e a maior parte da interface funciona corretamente.



### Melhoria de Desempenho

Melhorado o desempenho do gesto Clicar e Arrastar para "Deslocar e Navegar". \
Nos meus testes, o uso de CPU foi reduzido em ~50%!

**Contexto**

Durante o gesto "Deslocar e Navegar", o Mac Mouse Fix desenha um cursor de rato falso numa janela transparente, enquanto bloqueia o cursor de rato real no lugar. Isto garante que podes continuar a deslocar o elemento da interface em que começaste a deslocar, independentemente de quão longe moves o rato.

A melhoria de desempenho foi alcançada ao desativar o tratamento de eventos padrão do macOS nesta janela transparente, que não estava a ser usado de qualquer forma.





### Correções de Bugs

- Agora a ignorar eventos de deslocamento de tablets de desenho Wacom.
    - Antes, o Mac Mouse Fix estava a causar deslocamento errático em tablets Wacom, conforme reportado por @frenchie1980 no GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Obrigado!)
    
- Corrigido um bug onde o código Swift Concurrency, que foi introduzido como parte do novo sistema de licenciamento no Mac Mouse Fix 3.0.4, não executava na thread correta.
    - Isto causava crashes no macOS Tahoe, e provavelmente também causou outros bugs esporádicos relacionados com o licenciamento.
- Melhorada a robustez do código que descodifica licenças offline.
    - Isto contorna um problema nas APIs da Apple que fazia com que a validação de licenças offline falhasse sempre no meu Mac Mini Intel. Presumo que isto acontecia em todos os Macs Intel, e que foi a razão pela qual o bug "Dias grátis terminaram" (que já foi abordado na versão 3.0.4) ainda ocorria para algumas pessoas, conforme reportado por @toni20k5267 no GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Obrigado!)
        - Se experimentaste o bug "Dias grátis terminaram", peço desculpa por isso! Podes obter um reembolso [aqui](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Melhorias de UX

- Desativados os diálogos que forneciam soluções passo a passo para bugs do macOS que impediam os utilizadores de ativar o Mac Mouse Fix.
    - Estes problemas só ocorriam no macOS 13 Ventura e 14 Sonoma. Agora, estes diálogos só aparecem nas versões do macOS onde são relevantes. 
    - Os diálogos também são um pouco mais difíceis de acionar – antes, às vezes apareciam em situações onde não eram muito úteis.
    
- Adicionado um link "Ativar Licença" diretamente na notificação "Dias grátis terminaram". 
    - Isto torna a ativação de uma licença do Mac Mouse Fix ainda mais simples!

### Melhorias Visuais

- Ligeiramente melhorado o aspeto da janela "Atualização de Software". Agora encaixa melhor com o macOS 26 Tahoe. 
    - Isto foi feito ao personalizar o aspeto padrão da framework "Sparkle 1.27.3" que o Mac Mouse Fix usa para gerir atualizações.
- Corrigido o problema onde o texto na parte inferior do separador Acerca de estava às vezes cortado em chinês, ao tornar a janela ligeiramente mais larga.
- Corrigido o texto na parte inferior do separador Acerca de estar ligeiramente descentrado.
- Corrigido um bug que fazia com que o espaço sob a opção "Atalho de Teclado..." no separador Botões fosse demasiado pequeno. 

### Alterações Internas

- Removida a dependência da framework "SnapKit".
    - Isto reduz ligeiramente o tamanho da aplicação de 19,8 para 19,5 MB.
- Várias outras pequenas melhorias no código.

*Editado com excelente assistência do Claude.*

---

Vê também a versão anterior [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).