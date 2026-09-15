Mac Mouse Fix **2.2.1** gir full **støtte for macOS Ventura** blant andre endringer.

### Ventura-støtte!
Mac Mouse Fix støtter nå fullt ut og føles naturlig på macOS 13 Ventura.
Spesiell takk til [@chamburr](https://github.com/chamburr) som hjalp med Ventura-støtte i GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Endringer inkluderer:

- Oppdatert brukergrensesnittet for å gi tilgangstillatelser for å gjenspeile de nye Ventura Systeminnstillinger
- Mac Mouse Fix vil vises riktig under Venturas nye **Systeminnstillinger > Påloggingsobjekter**-meny
- Mac Mouse Fix vil reagere riktig når den er deaktivert under **Systeminnstillinger > Påloggingsobjekter**

### Droppet støtte for eldre macOS-versjoner

Dessverre lar Apple deg bare utvikle _for_ macOS 10.13 **High Sierra og nyere** når du utvikler _fra_ macOS 13 Ventura.

Så **minimum støttet versjon** har økt fra 10.11 El Capitan til 10.13 High Sierra.

### Feilrettinger

- Fikset et problem der Mac Mouse Fix endrer rulleoppførselen til noen **tegnebrett**. Se GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Fikset et problem der **tastatursnarveier** som inkluderer 'A'-tasten ikke kunne registreres. Fikser GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Fikset et problem der noen **knappetilordninger** ikke fungerte riktig ved bruk av et ikke-standard tastaturoppsett.
- Fikset en krasj i '**Appspesifikke innstillinger**' når du prøver å legge til en app uten en 'Bundle ID'. Kan hjelpe med GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Fikset en krasj når du prøver å legge til apper som ikke har et navn til '**Appspesifikke innstillinger**'. Løser GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Spesiell takk til [jeongtae](https://github.com/jeongtae) som var veldig hjelpsom med å finne ut av problemet!
- Flere små feilrettinger og forbedringer under panseret.