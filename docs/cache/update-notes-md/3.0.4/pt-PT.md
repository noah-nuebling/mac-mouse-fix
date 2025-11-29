O Mac Mouse Fix **3.0.4** melhora a privacidade, eficiência e fiabilidade.\
Introduz um novo sistema de licenciamento offline e corrige vários bugs importantes.

### Privacidade e Eficiência Melhoradas

A versão 3.0.4 introduz um novo sistema de validação de licenças offline que minimiza as ligações à internet tanto quanto possível.\
Isto melhora a privacidade e poupa recursos do sistema do teu computador.\
Quando licenciada, a aplicação funciona agora 100% offline!

<details>
<summary><b>Clica aqui para mais detalhes</b></summary>
As versões anteriores validavam as licenças online em cada arranque, permitindo potencialmente que registos de ligação fossem armazenados por servidores de terceiros (GitHub e Gumroad). O novo sistema elimina ligações desnecessárias – após a ativação inicial da licença, só se liga à internet se os dados locais da licença estiverem corrompidos.
<br><br>
Embora nenhum comportamento de utilizador tenha sido alguma vez registado por mim pessoalmente, o sistema anterior permitia teoricamente que servidores de terceiros registassem endereços IP e horários de ligação. A Gumroad também podia registar a tua chave de licença e potencialmente correlacioná-la com qualquer informação pessoal que tenha registado sobre ti quando compraste o Mac Mouse Fix.
<br><br>
Não considerei estas questões subtis de privacidade quando construí o sistema de licenciamento original, mas agora, o Mac Mouse Fix é tão privado e livre de internet quanto possível!
<br><br>
Consulta também a <a href=https://gumroad.com/privacy>política de privacidade da Gumroad</a> e este <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>comentário no GitHub</a> meu.

</details>

### Correções de Bugs

- Corrigido um bug em que o macOS às vezes ficava bloqueado ao usar 'Clicar e Arrastar' para 'Spaces e Mission Control'.
- Corrigido um bug em que os atalhos de teclado nas Definições do Sistema às vezes eram eliminados ao usar ações de 'Clique' do Mac Mouse Fix como 'Mission Control'.
- Corrigido [um bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) em que a aplicação às vezes parava de funcionar e mostrava uma notificação de que os 'Dias gratuitos terminaram' a utilizadores que já tinham comprado a aplicação.
    - Se experimentaste este bug, peço sinceras desculpas pelo incómodo. Podes solicitar um [reembolso aqui](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Melhorada a forma como a aplicação obtém a sua janela principal, o que pode ter corrigido um bug em que o ecrã 'Ativar Licença' às vezes não aparecia.

### Melhorias de Usabilidade

- Tornado impossível introduzir espaços e quebras de linha no campo de texto do ecrã 'Ativar Licença'.
    - Este era um ponto comum de confusão, porque é muito fácil selecionar acidentalmente uma quebra de linha oculta ao copiar a tua chave de licença dos emails da Gumroad.
- Estas notas de atualização são traduzidas automaticamente para utilizadores não anglófonos (Powered by Claude). Espero que seja útil! Se encontrares algum problema, avisa-me. Esta é uma primeira amostra de um novo sistema de tradução que tenho vindo a desenvolver ao longo do último ano.

### Suporte (Não Oficial) para macOS 10.14 Mojave Descontinuado

O Mac Mouse Fix 3 suporta oficialmente o macOS 11 Big Sur e versões posteriores. No entanto, para utilizadores dispostos a aceitar algumas falhas e problemas gráficos, o Mac Mouse Fix 3.0.3 e versões anteriores ainda podiam ser usados no macOS 10.14.4 Mojave.

O Mac Mouse Fix 3.0.4 descontinua esse suporte e **agora requer macOS 10.15 Catalina**. \
Peço desculpa por qualquer incómodo causado por isto. Esta alteração permitiu-me implementar o sistema de licenciamento melhorado usando funcionalidades modernas do Swift. Os utilizadores do Mojave podem continuar a usar o Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) ou a [versão mais recente do Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Espero que seja uma boa solução para todos.

### Melhorias Internas

- Implementado um novo sistema 'MFDataClass' que permite uma modelação de dados mais poderosa mantendo o ficheiro de configuração do Mac Mouse Fix legível e editável por humanos.
- Construído suporte para adicionar plataformas de pagamento além da Gumroad. Assim, no futuro, poderá haver checkouts localizados e a aplicação poderá ser vendida em diferentes países.
- Melhorado o registo de logs, o que me permite criar "Debug Builds" mais eficazes para utilizadores que experienciam bugs difíceis de reproduzir.
- Muitas outras pequenas melhorias e trabalho de limpeza.

*Editado com excelente assistência do Claude.*

---

Consulta também a versão anterior [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).