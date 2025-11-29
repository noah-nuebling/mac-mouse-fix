Mac Mouse Fix **3.0.4** melhora privacidade, eficiência e confiabilidade.\
Ele introduz um novo sistema de licenciamento offline e corrige vários bugs importantes.

### Privacidade e Eficiência Aprimoradas

A versão 3.0.4 introduz um novo sistema de validação de licença offline que minimiza conexões com a internet o máximo possível.\
Isso melhora a privacidade e economiza recursos do sistema do seu computador.\
Quando licenciado, o app agora opera 100% offline!

<details>
<summary><b>Clique aqui para mais detalhes</b></summary>
Versões anteriores validavam licenças online a cada inicialização, potencialmente permitindo que logs de conexão fossem armazenados por servidores de terceiros (GitHub e Gumroad). O novo sistema elimina conexões desnecessárias – após a ativação inicial da licença, ele só se conecta à internet se os dados locais da licença estiverem corrompidos.
<br><br>
Embora nenhum comportamento de usuário tenha sido registrado por mim pessoalmente, o sistema anterior teoricamente permitia que servidores de terceiros registrassem endereços IP e horários de conexão. O Gumroad também poderia registrar sua chave de licença e potencialmente correlacioná-la a qualquer informação pessoal que eles registraram sobre você quando você comprou o Mac Mouse Fix.
<br><br>
Eu não considerei essas questões sutis de privacidade quando construí o sistema de licenciamento original, mas agora, o Mac Mouse Fix é tão privado e livre de internet quanto possível!
<br><br>
Veja também a <a href=https://gumroad.com/privacy>política de privacidade do Gumroad</a> e este <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>comentário no GitHub</a> meu.

</details>

### Correções de Bugs

- Corrigido um bug onde o macOS às vezes travava ao usar 'Clicar e Arrastar' para 'Spaces e Mission Control'.
- Corrigido um bug onde atalhos de teclado nas Configurações do Sistema às vezes eram deletados ao usar ações de 'Clique' do Mac Mouse Fix como 'Mission Control'.
- Corrigido [um bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) onde o app às vezes parava de funcionar e mostrava uma notificação de que os 'Dias gratuitos acabaram' para usuários que já haviam comprado o app.
    - Se você experimentou este bug, peço sinceras desculpas pelo inconveniente. Você pode solicitar um [reembolso aqui](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Melhorado a forma como o aplicativo recupera sua janela principal, o que pode ter corrigido um bug onde a tela 'Ativar Licença' às vezes não aparecia.

### Melhorias de Usabilidade

- Tornado impossível inserir espaços e quebras de linha no campo de texto na tela 'Ativar Licença'.
    - Este era um ponto comum de confusão, porque é muito fácil selecionar acidentalmente uma quebra de linha oculta ao copiar sua chave de licença dos e-mails do Gumroad.
- Estas notas de atualização são traduzidas automaticamente para usuários não anglófonos (Powered by Claude). Espero que isso seja útil! Se você encontrar algum problema com isso, me avise. Este é um primeiro vislumbre de um novo sistema de tradução que venho desenvolvendo ao longo do último ano.

### Suporte (Não Oficial) para macOS 10.14 Mojave Descontinuado

O Mac Mouse Fix 3 oficialmente suporta macOS 11 Big Sur e posteriores. No entanto, para usuários dispostos a aceitar alguns problemas gráficos e falhas, o Mac Mouse Fix 3.0.3 e versões anteriores ainda podiam ser usados no macOS 10.14.4 Mojave.

O Mac Mouse Fix 3.0.4 descontinua esse suporte e **agora requer macOS 10.15 Catalina**. \
Peço desculpas por qualquer inconveniente causado por isso. Esta mudança me permitiu implementar o sistema de licenciamento aprimorado usando recursos modernos do Swift. Usuários do Mojave podem continuar usando o Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) ou a [versão mais recente do Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Espero que essa seja uma boa solução para todos.

### Melhorias Internas

- Implementado um novo sistema 'MFDataClass' permitindo modelagem de dados mais poderosa enquanto mantém o arquivo de configuração do Mac Mouse Fix legível e editável por humanos.
- Construído suporte para adicionar plataformas de pagamento além do Gumroad. Então, no futuro, pode haver checkouts localizados, e o app poderá ser vendido para diferentes países.
- Melhorado o sistema de logs que me permite criar "Debug Builds" mais eficazes para usuários que experimentam bugs difíceis de reproduzir.
- Muitas outras pequenas melhorias e trabalho de limpeza.

*Editado com excelente assistência do Claude.*

---

Confira também o lançamento anterior [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).