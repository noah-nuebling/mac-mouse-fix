Mac Mouse Fix **3.0.2** traz várias melhorias, incluindo **scrolling mais suave**, traduções aprimoradas e muito mais!

### Scrolling

- Agora podes parar as animações de scroll fazendo um movimento na direção oposta. Isto permite-te **'atirar'** e **'apanhar a página'** quando usas 'Suavidade: Alta', semelhante a um Trackpad.
- O Mac Mouse Fix agora envia eventos de scroll mais cedo no ciclo de atualização do ecrã, dando às aplicações mais tempo para processar os eventos e mostrar o scrolling suavemente. Isto **melhora as taxas de frames**, especialmente em websites complexos como o YouTube.com.
- Melhorou a capacidade de resposta da configuração 'Suavidade: Alta', tornando o scrolling mais fácil de controlar.
- Melhorou um mecanismo introduzido no 3.0.1 onde a velocidade da animação aumenta conforme moves a roda do rato mais rapidamente quando usas 'Suavidade: Regular'. No 3.0.2, o aumento da velocidade da animação deve aparecer mais consistente e previsível, tornando-o mais agradável aos olhos enquanto oferece um excelente controlo.
- Corrigido um problema onde a velocidade de scrolling estava muito lenta, especialmente ao usar a opção 'Precisão'. Este problema foi introduzido no 3.0.1. Obrigado a @V-Coba por chamar a atenção para isto em [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- Melhorado o comportamento dentro do navegador Arc quando se usa 'Clicar e Scroll' para 'Aumentar ou Diminuir Zoom'.

### Localização

- Atualizadas as traduções em 🇻🇳 Vietnamita. Créditos para @nghlt!
- Melhoradas algumas traduções em 🇩🇪 Alemão.
- O texto dentro do Mac Mouse Fix que não tem tradução para o idioma atual agora mostrará um valor provisório em vez de ficar em branco. Isto deve tornar menos confusa a navegação na aplicação quando existem traduções em falta.

### Outros

- O Mac Mouse Fix agora mostrará uma notificação com um link para [este guia](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) aos utilizadores que possam estar a experienciar um bug no macOS 13 Ventura e posteriores que pode impedir que o Mac Mouse Fix seja ativado.
- Alteradas as configurações padrão para ratos com 3 botões. As configurações padrão já não incluem uma ação 'Clicar e Scroll' para o Botão da Roda de Scroll, já que isso é bastante difícil de executar. Em vez disso, as configurações padrão agora incluem uma ação de 'Pressionar' e 'Duplo Clique'.
- Adicionada uma dica de ferramenta ao ícone do Mac Mouse Fix no separador Sobre. Indica-te como revelar o ficheiro de configuração do Mac Mouse Fix no Finder.
- Muitas melhorias e limpezas nos bastidores.

---

Confere também o lançamento anterior [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).