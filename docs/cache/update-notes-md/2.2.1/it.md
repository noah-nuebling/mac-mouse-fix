Mac Mouse Fix **2.2.1** offre pieno **supporto per macOS Ventura** tra le altre modifiche.

### Supporto per Ventura!
Mac Mouse Fix ora supporta completamente e si integra nativamente con macOS 13 Ventura.
Un ringraziamento speciale a [@chamburr](https://github.com/chamburr) che ha contribuito al supporto di Ventura nella Issue GitHub [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Le modifiche includono:

- Aggiornata l'interfaccia per la concessione dell'Accesso Accessibilità per riflettere le nuove Impostazioni di Sistema di Ventura
- Mac Mouse Fix verrà visualizzato correttamente nel nuovo menu **Impostazioni di Sistema > Elementi Login** di Ventura
- Mac Mouse Fix reagirà correttamente quando viene disattivato in **Impostazioni di Sistema > Elementi Login**

### Rimosso il supporto per le versioni precedenti di macOS

Purtroppo, Apple permette di sviluppare _per_ macOS 10.13 **High Sierra e successivi** solo quando si sviluppa _da_ macOS 13 Ventura.

Quindi la **versione minima supportata** è passata da 10.11 El Capitan a 10.13 High Sierra.

### Correzioni di bug

- Risolto un problema per cui Mac Mouse Fix modificava il comportamento dello scorrimento di alcune **tavolette grafiche**. Vedi Issue GitHub [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Risolto un problema per cui non era possibile registrare **scorciatoie da tastiera** che includevano il tasto 'A'. Risolve Issue GitHub [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Risolto un problema per cui alcune **riassegnazioni dei pulsanti** non funzionavano correttamente quando si utilizzava un layout di tastiera non standard.
- Risolto un crash nelle '**Impostazioni specifiche per app**' quando si tentava di aggiungere un'app senza 'Bundle ID'. Potrebbe risolvere Issue GitHub [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Risolto un crash quando si tentava di aggiungere app senza nome nelle '**Impostazioni specifiche per app**'. Risolve Issue GitHub [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Un ringraziamento speciale a [jeongtae](https://github.com/jeongtae) che è stato molto utile nel individuare il problema!
- Altre piccole correzioni di bug e miglioramenti sotto il cofano.