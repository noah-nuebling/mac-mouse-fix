Kolla även in de **snygga ändringarna** som infördes i [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

**3.0.0 Beta 5** återställer **kompatibilitet** med vissa **möss** under macOS 13 Ventura och **fixar scrollning** i många appar.
Den innehåller också flera andra små fixar och förbättringar för användarupplevelsen.

Här är **alla nyheter**:

### Mus

- Fixad scrollning i Terminal och andra appar! Se GitHub-ärende [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Fixad inkompatibilitet med vissa möss under macOS 13 Ventura genom att gå bort från opålitliga Apple-API:er till förmån för lågnivåhackar. Hoppas detta inte skapar nya problem - meddela mig om det gör det! Särskilt tack till Maria och GitHub-användaren [samiulhsnt](https://github.com/samiulhsnt) för hjälpen att lista ut detta! Se GitHub-ärende [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) för mer information.
- Använder inte längre någon CPU vid klick på musknapp 1 eller 2. Något lägre CPU-användning vid klick på andra knappar.
    - Detta är en "Debug Build" så CPU-användningen kan vara omkring 10 gånger högre vid knappklick i denna beta jämfört med slutversionen
- Trackpad-scrollningssimuleringen som används för Mac Mouse Fix "Smooth Scrolling" och "Scroll & Navigate"-funktioner är nu ännu mer exakt. Detta kan leda till bättre beteende i vissa situationer.

### Gränssnitt

- Automatisk fixning av problem med att bevilja åtkomst till Tillgänglighet efter uppdatering från en äldre version av Mac Mouse Fix. Antar ändringarna som beskrivs i [2.2.2 Release Notes](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Lagt till en "Avbryt"-knapp på skärmen "Bevilja åtkomst till Tillgänglighet"
- Fixat ett problem där konfigurering av Mac Mouse Fix inte fungerade korrekt efter installation av en ny version av Mac Mouse Fix, eftersom den nya versionen anslöt till den gamla versionen av "Mac Mouse Fix Helper". Nu kommer Mac Mouse Fix inte längre ansluta till den gamla "Mac Mouse Fix Helper" och inaktiverar den gamla versionen automatiskt när det är lämpligt.
- Ger användaren instruktioner om hur man fixar ett problem där Mac Mouse Fix inte kan aktiveras korrekt på grund av att en annan version av Mac Mouse Fix finns i systemet. Detta problem uppstår endast under macOS Ventura.
- Förbättrat beteende och animationer på skärmen "Bevilja åtkomst till Tillgänglighet"
- Mac Mouse Fix kommer att hamna i förgrunden när den aktiveras. Detta förbättrar UI-interaktioner i vissa situationer, som när du aktiverar Mac Mouse Fix efter att den inaktiverats under Systeminställningar > Allmänt > Inloggningsobjekt.
- Förbättrade UI-texter på skärmen "Bevilja åtkomst till Tillgänglighet"
- Förbättrade UI-texter som visas när man försöker aktivera Mac Mouse Fix medan den är inaktiverad i Systeminställningar
- Fixat en tysk UI-text

### Under huven

- Byggversionerna av "Mac Mouse Fix" och den inbäddade "Mac Mouse Fix Helper" är nu synkroniserade. Detta används för att förhindra att "Mac Mouse Fix" av misstag ansluter till gamla versioner av "Mac Mouse Fix Helper".
- Fixat problem där viss data kring din licens och testperiod ibland visades felaktigt vid första start av appen genom att ta bort cache-data från den initiala konfigurationen
- Mycket upprensning av projektstrukturen och källkoden
- Förbättrade felsökningsmeddelanden

---

### Hur du kan hjälpa till

Du kan hjälpa till genom att dela dina **idéer**, **problem** och **feedback**!

Bästa stället att dela dina **idéer** och **problem** är [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Bästa stället att ge **snabb** ostrukturerad feedback är [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Du kan också nå dessa platser inifrån appen på fliken "**ⓘ Om**".

**Tack** för att du hjälper till att göra Mac Mouse Fix bättre! 💙💛❤️