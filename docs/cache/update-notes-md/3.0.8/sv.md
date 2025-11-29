Mac Mouse Fix **3.0.8** löser UI-problem och mer.

### **UI-problem**

- Inaktiverade den nya designen på macOS 26 Tahoe. Nu kommer appen att se ut och fungera som den gjorde på macOS 15 Sequoia.
    - Jag gjorde detta eftersom några av Apples omdesignade UI-element fortfarande har problem. Till exempel var '-'-knapparna på fliken 'Knappar' inte alltid klickbara.
    - UI:t kan se lite föråldrat ut på macOS 26 Tahoe nu. Men det bör vara fullt funktionellt och polerat precis som tidigare.
- Fixade en bugg där notifikationen 'Gratisdagarna är över' fastnade i skärmens övre högra hörn.
    - Tack till [Sashpuri](https://github.com/Sashpuri) och andra för att ni rapporterade det!

### **UI-polering**

- Inaktiverade den gröna trafikljusknappen i Mac Mouse Fix huvudfönster.
    - Knappen gjorde ingenting, eftersom fönstret inte kan storleksändras manuellt.
- Fixade ett problem där några av de horisontella linjerna i tabellen på fliken 'Knappar' var för mörka under macOS 26 Tahoe.
- Fixade en bugg där meddelandet "Primär musknapp kan inte användas" på fliken 'Knappar' ibland blev avklippt under macOS 26 Tahoe.
- Fixade ett stavfel i det tyska gränssnittet. Med tillstånd av GitHub-användaren [i-am-the-slime](https://github.com/i-am-the-slime). Tack!
- Löste ett problem där MMF-fönstret ibland kort blinkade i fel storlek när fönstret öppnades på macOS 26 Tahoe.

### **Andra ändringar**

- Förbättrat beteende när man försöker aktivera Mac Mouse Fix medan flera instanser av Mac Mouse Fix körs på datorn.
    - Mac Mouse Fix kommer nu att försöka inaktivera den andra instansen av Mac Mouse Fix mer ihärdigt.
    - Detta kan förbättra specialfall där Mac Mouse Fix inte kunde aktiveras.
- Under-huven-ändringar och städning.

---

Kolla även in vad som är nytt i föregående version [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).