Mac Mouse Fix **3.0.3** je připraven pro macOS 15 Sequoia. Opravuje také některé problémy se stabilitou a přináší několik drobných vylepšení.

### Podpora macOS 15 Sequoia

Aplikace nyní správně funguje pod macOS 15 Sequoia!

- Většina animací uživatelského rozhraní nefungovala pod macOS 15 Sequoia. Nyní vše opět funguje správně!
- Zdrojový kód je nyní možné sestavit pod macOS 15 Sequoia. Dříve byly problémy s kompilátorem Swift, které bránily sestavení aplikace.

### Řešení pádů při scrollování

Od verze Mac Mouse Fix 3.0.2 se objevilo [několik hlášení](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) o tom, že se Mac Mouse Fix při scrollování periodicky vypíná a znovu zapíná. Bylo to způsobeno pádem aplikace na pozadí 'Mac Mouse Fix Helper'. Tato aktualizace se snaží tyto pády opravit následujícími změnami:

- Mechanismus scrollování se pokusí obnovit a pokračovat v běhu místo pádu, když narazí na okrajový případ, který se zdá být příčinou těchto pádů.
- Změnil jsem způsob, jakým aplikace obecněji zpracovává neočekávané stavy: Místo okamžitého pádu se nyní aplikace v mnoha případech pokusí z neočekávaných stavů zotavit.
    
    - Tato změna přispívá k opravám pádů při scrollování popsaných výše. Může také zabránit dalším pádům.
  
Poznámka: Nikdy jsem tyto pády nedokázal reprodukovat na svém počítači a stále si nejsem jistý, co je způsobilo, ale na základě hlášení, která jsem obdržel, by tato aktualizace měla všem pádům zabránit. Pokud stále zažíváš pády při scrollování nebo pokud jsi pády zažíval ve verzi 3.0.2, bylo by cenné, kdybys sdílel svou zkušenost a diagnostická data v GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Pomohlo by mi to pochopit problém a vylepšit Mac Mouse Fix. Děkuji!

### Řešení trhání při scrollování

Ve verzi 3.0.2 jsem provedl změny v tom, jak Mac Mouse Fix posílá události scrollování do systému, ve snaze snížit trhání při scrollování pravděpodobně způsobené problémy s Apple VSync API.

Po rozsáhlejším testování a zpětné vazbě se však zdá, že nový mechanismus ve verzi 3.0.2 dělá scrollování plynulejším v některých scénářích, ale trhanějším v jiných. Zejména ve Firefoxu to bylo znatelně horší. \
Celkově nebylo jasné, že nový mechanismus skutečně zlepšil trhání při scrollování plošně. Také mohl přispět k pádům při scrollování popsaným výše.

Proto jsem nový mechanismus vypnul a vrátil mechanismus VSync pro události scrollování zpět na to, jak to bylo v Mac Mouse Fix 3.0.0 a 3.0.1.

Více informací najdeš v GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875).

### Vrácení peněz

Omlouvám se za potíže související se změnami scrollování ve verzích 3.0.1 a 3.0.2. Výrazně jsem podcenil problémy, které s tím přijdou, a byl jsem pomalý v řešení těchto problémů. Udělám maximum, abych se z této zkušenosti poučil a byl opatrnější s takovými změnami v budoucnu. Rád bych také nabídl vrácení peněz všem, kterých se to dotklo. Pokud máš zájem, klikni [sem](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

### Chytřejší mechanismus aktualizací

Tyto změny byly převzaty z Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) a [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Podívej se na jejich poznámky k vydání, kde se dozvíš více o detailech. Zde je shrnutí:

- Je tu nový, chytřejší mechanismus, který rozhoduje, kterou aktualizaci uživateli zobrazit.
- Přechod z aktualizačního frameworku Sparkle 1.26.0 na nejnovější Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- Okno, které aplikace zobrazuje, aby tě informovala o dostupnosti nové verze Mac Mouse Fix, nyní podporuje JavaScript, což umožňuje hezčí formátování poznámek k aktualizaci.

### Další vylepšení a opravy chyb

- Opraven problém, kdy se cena aplikace a související informace zobrazovaly nesprávně na kartě 'O aplikaci' v některých případech.
- Opraven problém, kdy mechanismus pro synchronizaci plynulého scrollování s obnovovací frekvencí displeje nefungoval správně při používání více displejů.
- Spousta drobných vylepšení a úprav pod kapotou.

---

Podívej se také na předchozí vydání [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).