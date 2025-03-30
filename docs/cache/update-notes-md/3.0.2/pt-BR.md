Mac Mouse Fix **3.0.2** traz várias melhorias, incluindo **rolagem mais suave**, traduções aprimoradas e muito mais!

### Rolagem

- Agora você pode interromper as animações de rolagem rolando um passo na direção oposta. Isso permite **'lançar'** e **'capturar a página'** ao usar 'Suavidade: Alta', similar a um Trackpad.
- Mac Mouse Fix agora envia eventos de rolagem mais cedo no ciclo de atualização da tela, dando aos aplicativos mais tempo para processar os eventos de rolagem e exibir a rolagem suavemente. Isso **melhora as taxas de quadros**, especialmente em sites complexos como YouTube.com.
- Melhorou a capacidade de resposta da configuração 'Suavidade: Alta', tornando a rolagem mais fácil de controlar.
- Aprimorou um mecanismo introduzido no 3.0.1 onde a velocidade da animação aumenta conforme você move a roda de rolagem mais rapidamente ao usar 'Suavidade: Regular'. No 3.0.2, a aceleração da animação deve aparecer mais consistente e previsível, tornando-a mais agradável aos olhos enquanto fornece ótimo controle.
- Corrigiu um problema onde a velocidade de rolagem estava muito lenta, especialmente ao usar a opção 'Precisão'. Este problema foi introduzido no 3.0.1. Agradecimentos ao @V-Coba por chamar atenção para isso em [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- Melhorou o comportamento dentro do navegador Arc ao usar 'Clicar e Rolar' para 'Aumentar ou Diminuir Zoom'.

### Localização

- Atualizou as traduções para 🇻🇳 Vietnamita. Créditos para @nghlt!
- Melhorou algumas traduções em 🇩🇪 Alemão.
- Texto dentro do Mac Mouse Fix que não possui tradução para o idioma atual agora mostrará um valor provisório em vez de ficar em branco. Isso deve tornar menos confusa a navegação no aplicativo quando houver traduções faltando.

### Outros

- Mac Mouse Fix agora mostrará uma notificação com um link para [este guia](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) para usuários que podem estar experimentando um bug no macOS 13 Ventura e posteriores que pode impedir que o Mac Mouse Fix seja ativado.
- Alterou as configurações padrão para mouses com 3 botões. As configurações padrão não apresentam mais uma ação 'Clicar e Rolar' para o Botão da Roda de Rolagem, já que isso é bastante difícil de executar. Em vez disso, as configurações padrão agora apresentam uma ação de 'Segurar' e 'Duplo Clique'.
- Adicionou uma dica de ferramenta ao ícone do Mac Mouse Fix na aba Sobre. Ela mostra como revelar o arquivo de configuração do Mac Mouse Fix no Finder.
- Muitas melhorias e limpezas nos bastidores.

---

Confira também o lançamento anterior [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).