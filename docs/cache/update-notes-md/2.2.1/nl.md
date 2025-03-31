Mac Mouse Fix **2.2.1** biedt volledige **ondersteuning voor macOS Ventura** en andere wijzigingen.

### Ventura-ondersteuning!
Mac Mouse Fix ondersteunt nu volledig macOS 13 Ventura en voelt er natuurlijk aan.
Speciale dank aan [@chamburr](https://github.com/chamburr) die hielp met Ventura-ondersteuning in GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Wijzigingen omvatten:

- Bijgewerkte UI voor het verlenen van Toegankelijkheid om de nieuwe Ventura Systeeminstellingen weer te geven
- Mac Mouse Fix wordt correct weergegeven onder Ventura's nieuwe **Systeeminstellingen > Inlogitems** menu
- Mac Mouse Fix reageert correct wanneer het wordt uitgeschakeld onder **Systeeminstellingen > Inlogitems**

### Ondersteuning voor oudere macOS-versies vervallen

Helaas staat Apple alleen toe om _voor_ macOS 10.13 **High Sierra en later** te ontwikkelen wanneer je ontwikkelt _vanaf_ macOS 13 Ventura.

De **minimaal ondersteunde versie** is daarom verhoogd van 10.11 El Capitan naar 10.13 High Sierra.

### Bugfixes

- Een probleem opgelost waarbij Mac Mouse Fix het scrollgedrag van sommige **tekentabletten** veranderde. Zie GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Een probleem opgelost waarbij **sneltoetsen** met de 'A'-toets niet konden worden opgenomen. Lost GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275) op.
- Een probleem opgelost waarbij sommige **knoptoewijzingen** niet correct werkten bij gebruik van een niet-standaard toetsenbordindeling.
- Een crash in '**App-specifieke instellingen**' opgelost bij het toevoegen van een app zonder 'Bundle ID'. Kan helpen met GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Een crash opgelost bij het toevoegen van apps zonder naam aan '**App-specifieke instellingen**'. Lost GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241) op. Speciale dank aan [jeongtae](https://github.com/jeongtae) die erg behulpzaam was bij het uitzoeken van het probleem!
- Meer kleine bugfixes en verbeteringen onder de motorkap.