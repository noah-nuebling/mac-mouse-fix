Mac Mouse Fix **3.0.5** opravuje několik chyb, zlepšuje výkon a přidává aplikaci trochu lesku. \
Je také kompatibilní s macOS 26 Tahoe.

### Vylepšená simulace rolování trackpadu

- Systém rolování nyní dokáže simulovat klepnutí dvěma prsty na trackpad, aby aplikace přestaly rolovat.
    - Toto opravuje problém při spouštění aplikací pro iPhone nebo iPad, kde rolování často pokračovalo i poté, co se uživatel rozhodl zastavit.
- Opravena nekonzistentní simulace zvednutí prstů z trackpadu.
    - To mohlo v některých situacích způsobovat neoptimální chování.



### Kompatibilita s macOS 26 Tahoe

Při spuštění beta verze macOS 26 Tahoe je nyní aplikace použitelná a většina uživatelského rozhraní funguje správně.



### Vylepšení výkonu

Vylepšen výkon gesta Kliknutí a přetažení pro "Rolování a navigaci". \
Při mém testování se spotřeba CPU snížila přibližně o 50 %!

**Pozadí**

Během gesta "Rolování a navigace" Mac Mouse Fix vykresluje falešný kurzor myši v průhledném okně a zároveň zamyká skutečný kurzor myši na místě. To zajišťuje, že můžeš pokračovat v rolování prvku uživatelského rozhraní, na kterém jsi začal/a rolovat, bez ohledu na to, jak daleko pohneš myší.

Vylepšeného výkonu bylo dosaženo vypnutím výchozího zpracování událostí macOS v tomto průhledném okně, které stejně nebylo využíváno.





### Opravy chyb

- Nyní se ignorují události rolování z kreslicích tabletů Wacom.
    - Dříve Mac Mouse Fix způsoboval chaotické rolování na tabletech Wacom, jak nahlásil @frenchie1980 v GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Díky!)
    
- Opravena chyba, kdy kód Swift Concurrency, který byl zaveden jako součást nového licenčního systému v Mac Mouse Fix 3.0.4, neběžel ve správném vlákně.
    - To způsobovalo pády na macOS Tahoe a pravděpodobně také způsobovalo další sporadické chyby kolem licencování.
- Vylepšena robustnost kódu, který dekóduje offline licence.
    - Toto obchází problém v API Apple, který způsoboval, že validace offline licencí vždy selhávala na mém Intel Mac Mini. Předpokládám, že se to dělo na všech Intel Macích a že to byl důvod, proč chyba "Bezplatné dny skončily" (která již byla řešena ve verzi 3.0.4) stále přetrvávala u některých lidí, jak nahlásil @toni20k5267 v GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Děkuji!)
        - Pokud jsi zažil/a chybu "Bezplatné dny skončily", omlouvám se! Můžeš získat refundaci [zde](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Vylepšení uživatelské zkušenosti

- Zakázány dialogy, které poskytovaly krok za krokem řešení chyb macOS, které bránily uživatelům v povolení Mac Mouse Fix.
    - Tyto problémy se vyskytovaly pouze na macOS 13 Ventura a 14 Sonoma. Nyní se tyto dialogy zobrazují pouze na těch verzích macOS, kde jsou relevantní.
    - Dialogy se také hůře spouštějí – dříve se někdy zobrazovaly v situacích, kdy nebyly příliš užitečné.
    
- Přidán odkaz "Aktivovat licenci" přímo na oznámení "Bezplatné dny skončily".
    - To dělá aktivaci licence Mac Mouse Fix ještě bezproblémovější!

### Vizuální vylepšení

- Mírně vylepšen vzhled okna "Aktualizace softwaru". Nyní lépe ladí s macOS 26 Tahoe.
    - Toho bylo dosaženo přizpůsobením výchozího vzhledu frameworku "Sparkle 1.27.3", který Mac Mouse Fix používá ke správě aktualizací.
- Opraven problém, kdy byl text ve spodní části záložky O aplikaci někdy oříznutý v čínštině, rozšířením okna.
- Opraven text ve spodní části záložky O aplikaci, který byl mírně mimo střed.
- Opravena chyba, která způsobovala, že prostor pod možností "Klávesová zkratka..." na záložce Tlačítka byl příliš malý.

### Změny pod kapotou

- Odstraněna závislost na frameworku "SnapKit".
    - To mírně snižuje velikost aplikace z 19,8 na 19,5 MB.
- Různá další drobná vylepšení v kódové základně.

*Upraveno s vynikající asistencí Claude.*

---

Podívej se také na předchozí vydání [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).