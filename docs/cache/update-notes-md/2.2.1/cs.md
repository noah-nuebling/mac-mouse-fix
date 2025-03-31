Mac Mouse Fix **2.2.1** přináší plnou **podporu pro macOS Ventura** a další změny.

### Podpora Ventury!
Mac Mouse Fix nyní plně podporuje macOS 13 Ventura a působí jako nativní aplikace.
Speciální poděkování [@chamburr](https://github.com/chamburr), který pomohl s podporou Ventury v GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Změny zahrnují:

- Aktualizované UI pro udělení přístupu k Usnadnění, které odráží nové Systémové nastavení ve Ventuře
- Mac Mouse Fix se bude správně zobrazovat v novém menu Ventury **Systémové nastavení > Položky při přihlášení**
- Mac Mouse Fix bude správně reagovat, když bude vypnutý v **Systémové nastavení > Položky při přihlášení**

### Ukončení podpory starších verzí macOS

Bohužel Apple umožňuje vyvíjet _pro_ macOS 10.13 **High Sierra a novější** pouze při vývoji _z_ macOS 13 Ventura.

Takže **minimální podporovaná verze** se zvýšila z 10.11 El Capitan na 10.13 High Sierra.

### Opravy chyb

- Opravena chyba, kdy Mac Mouse Fix měnil chování scrollování u některých **grafických tabletů**. Viz GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Opravena chyba, kdy nebylo možné zaznamenat **klávesové zkratky** obsahující klávesu 'A'. Opravuje GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Opravena chyba, kdy některá **přemapování tlačítek** nefungovala správně při použití nestandardního rozložení klávesnice.
- Opravena chyba v '**Nastavení pro konkrétní aplikace**' při pokusu o přidání aplikace bez 'Bundle ID'. Může pomoct s GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Opravena chyba při pokusu o přidání aplikací bez názvu do '**Nastavení pro konkrétní aplikace**'. Řeší GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Speciální poděkování [jeongtae](https://github.com/jeongtae), který velmi pomohl s odhalením problému!
- Další drobné opravy chyb a vylepšení pod kapotou.