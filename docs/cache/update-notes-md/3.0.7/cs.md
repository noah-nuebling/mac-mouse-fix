Mac Mouse Fix **3.0.7** řeší několik důležitých chyb.

### Opravy chyb

- Aplikace opět funguje na **starších verzích macOS** (macOS 10.15 Catalina a macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 nebylo možné povolit na těchto verzích macOS, protože vylepšená funkce 'Zpět' a 'Vpřed' zavedená v Mac Mouse Fix 3.0.6 se pokoušela použít systémová API macOS, která nebyla dostupná.
- Opraveny problémy s funkcí **'Zpět' a 'Vpřed'**
    - Vylepšená funkce 'Zpět' a 'Vpřed' zavedená v Mac Mouse Fix 3.0.6 nyní bude vždy používat 'hlavní vlákno' k dotazování macOS, jaké stisky kláves simulovat pro přechod zpět a vpřed v aplikaci, kterou používáš. \
    To může zabránit pádům a nespolehlivému chování v některých situacích.
- Pokus o opravu chyby, kdy se **nastavení náhodně resetovala** (Viz tyto [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Přepsal jsem kód, který načítá konfigurační soubor pro Mac Mouse Fix, aby byl robustnější. Když došlo ke vzácným chybám souborového systému macOS, starý kód mohl někdy mylně usoudit, že je konfigurační soubor poškozený, a resetovat ho na výchozí hodnoty.
- Snížena pravděpodobnost chyby, kdy **přestane fungovat scrollování**     
     - Tuto chybu nelze plně vyřešit bez hlubších změn, které by pravděpodobně způsobily jiné problémy. \
      Nicméně prozatím jsem snížil časové okno, kdy může v systému scrollování dojít k 'deadlocku', což by mělo alespoň snížit pravděpodobnost výskytu této chyby. To také činí scrollování o něco efektivnější. 
    - Tato chyba má podobné příznaky – ale myslím, že jinou základní příčinu – jako chyba 'Scroll Stops Working Intermittently', která byla řešena v minulém vydání 3.0.6.
    - (Díky Joonasovi za diagnostiku!) 

Děkuji všem za hlášení chyb! 

---

Podívej se také na předchozí vydání [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).