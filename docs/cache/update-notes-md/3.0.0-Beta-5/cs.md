Podívejte se také na **skvělé změny** představené v [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

**3.0.0 Beta 5** obnovuje **kompatibilitu** s některými **myšmi** v macOS 13 Ventura a **opravuje scrollování** v mnoha aplikacích.
Obsahuje také několik dalších drobných oprav a vylepšení kvality života.

Zde je **vše nové**:

### Myš

- Opraveno scrollování v Terminálu a dalších aplikacích! Viz GitHub problém [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Opravena nekompatibilita s některými myšmi v macOS 13 Ventura přechodem od nespolehlivých Apple API k nízkoúrovňovým hackům. Doufám, že to nepřinese nové problémy - dejte mi vědět, pokud ano! Speciální poděkování Marii a GitHub uživateli [samiulhsnt](https://github.com/samiulhsnt) za pomoc při řešení tohoto problému! Více informací najdete v GitHub problému [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424).
- Nebude již využívat CPU při klikání na tlačítka myši 1 nebo 2. Mírně sníženo využití CPU při klikání na ostatní tlačítka.
    - Toto je "Debug Build", takže využití CPU může být při klikání na tlačítka v této betě až 10krát vyšší než ve finální verzi
- Simulace scrollování trackpadu, která se používá pro funkce "Plynulé scrollování" a "Scrollování & Navigace" v Mac Mouse Fix, je nyní ještě přesnější. To může v některých situacích vést k lepšímu chování.

### UI

- Automatické opravování problémů s udělením přístupu k Accessibility po aktualizaci ze starší verze Mac Mouse Fix. Přejímá změny popsané v [poznámkách k vydání 2.2.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Přidáno tlačítko "Zrušit" na obrazovce "Udělit přístup k Accessibility"
- Opraven problém, kdy konfigurace Mac Mouse Fix nefungovala správně po instalaci nové verze Mac Mouse Fix, protože se nová verze připojovala ke staré verzi "Mac Mouse Fix Helper". Nyní se Mac Mouse Fix již nebude připojovat ke starému "Mac Mouse Fix Helper" a v případě potřeby starou verzi automaticky deaktivuje.
- Poskytnutí instrukcí uživateli, jak opravit problém, kdy Mac Mouse Fix nelze správně povolit kvůli přítomnosti jiné verze Mac Mouse Fix v systému. Tento problém se vyskytuje pouze v macOS Ventura.
- Vylepšeno chování a animace na obrazovce "Udělit přístup k Accessibility"
- Mac Mouse Fix bude přesunut do popředí, když je povolen. To zlepšuje interakce s UI v některých situacích, například když povolíte Mac Mouse Fix poté, co byl zakázán v Systémových nastaveních > Obecné > Přihlašovací položky.
- Vylepšeny texty UI na obrazovce "Udělit přístup k Accessibility"
- Vylepšeny texty UI, které se zobrazují při pokusu o povolení Mac Mouse Fix, když je zakázán v Systémových nastaveních
- Opraven německý text v UI

### Pod kapotou

- Číslo sestavení "Mac Mouse Fix" a vloženého "Mac Mouse Fix Helper" jsou nyní synchronizovány. To se používá k zabránění "Mac Mouse Fix" v náhodném připojení ke starým verzím "Mac Mouse Fix Helper".
- Opraven problém, kdy se některá data o vaší licenci a zkušební době někdy zobrazovala nesprávně při prvním spuštění aplikace odstraněním dat mezipaměti z počáteční konfigurace
- Spousta úklidu ve struktuře projektu a zdrojovém kódu
- Vylepšeny ladící zprávy

---

### Jak můžete pomoci

Můžete pomoci sdílením vašich **nápadů**, **problémů** a **zpětné vazby**!

Nejlepším místem pro sdílení vašich **nápadů** a **problémů** je [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Nejlepším místem pro poskytnutí **rychlé** nestrukturované zpětné vazby je [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

K těmto místům se můžete dostat také přímo z aplikace na záložce "**ⓘ O aplikaci**".

**Děkuji** za pomoc při vylepšování Mac Mouse Fix! 💙💛❤️