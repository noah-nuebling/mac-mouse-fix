Mac Mouse Fix **3.0.1** přináší několik oprav chyb a vylepšení, spolu s **novým jazykem**!

### Byla přidána vietnamština!

Mac Mouse Fix je nyní dostupný ve 🇻🇳 vietnamštině. Velké díky uživateli @nghlt [na GitHubu](https://GitHub.com/nghlt)!


### Opravy chyb

- Mac Mouse Fix nyní správně funguje s **Rychlým přepínáním uživatelů**!
  - Rychlé přepínání uživatelů je, když se přihlásíte do druhého účtu macOS bez odhlášení z prvního účtu.
  - Před touto aktualizací přestalo po rychlém přepnutí uživatele fungovat scrollování. Nyní by mělo vše fungovat správně.
- Opravena drobná chyba, kdy bylo rozložení karty Tlačítka příliš široké po prvním spuštění Mac Mouse Fix.
- Vylepšena spolehlivost pole '+' při rychlém přidávání několika Akcí za sebou.
- Opravena nejasná chyba nahlášená uživatelem @V-Coba v Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Další vylepšení

- **Scrollování je více responzivní** při použití nastavení 'Plynulost: Běžná'.
  - Rychlost animace se nyní zvyšuje s rychlejším otáčením kolečka myši. Díky tomu je scrollování při rychlém pohybu responzivnější, zatímco při pomalém scrollování zůstává stejně plynulé.
  
- **Zrychlení scrollování** je nyní stabilnější a předvídatelnější.
- Implementován mechanismus pro **zachování vašich nastavení** při aktualizaci na novou verzi Mac Mouse Fix.
  - Dříve Mac Mouse Fix resetoval všechna vaše nastavení po aktualizaci na novou verzi, pokud se změnila struktura nastavení. Nyní se Mac Mouse Fix pokusí aktualizovat strukturu vašich nastavení a zachovat vaše preference.
  - Zatím to funguje pouze při aktualizaci z verze 3.0.0 na 3.0.1. Pokud aktualizujete ze starší verze než 3.0.0, nebo pokud provádíte _downgrade_ z 3.0.1 _na_ předchozí verzi, vaše nastavení budou stále resetována.
- Rozložení karty Tlačítka se nyní lépe přizpůsobuje šířce různých jazyků.
- Vylepšení [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) a dalších dokumentů.
- Vylepšené lokalizační systémy. Překladové soubory jsou nyní automaticky čištěny a analyzovány na potenciální problémy. K dispozici je nový [Průvodce lokalizací](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731), který obsahuje automaticky zjištěné problémy spolu s dalšími užitečnými informacemi a pokyny pro lidi, kteří chtějí pomoci s překladem Mac Mouse Fix. Odstraněna závislost na nástroji [BartyCrouch](https://github.com/FlineDev/BartyCrouch), který byl dříve používán pro získání některých těchto funkcí.
- Vylepšeno několik UI textů v angličtině a němčině.
- Spousta vylepšení a úprav pod kapotou.

---

Podívejte se také na poznámky k vydání [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - dosud největší aktualizace Mac Mouse Fix!