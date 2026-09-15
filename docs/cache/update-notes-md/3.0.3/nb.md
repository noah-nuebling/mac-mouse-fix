Mac Mouse Fix **3.0.3** er klar for macOS 15 Sequoia. Den fikser også noen stabilitetsproblemer og gir flere små forbedringer.

### macOS 15 Sequoia-støtte

Appen fungerer nå ordentlig under macOS 15 Sequoia!

- De fleste UI-animasjoner var ødelagt under macOS 15 Sequoia. Nå fungerer alt ordentlig igjen!
- Kildekoden kan nå bygges under macOS 15 Sequoia. Tidligere var det problemer med Swift-kompilatoren som forhindret appen fra å bygges.

### Løser rullekrasj

Siden Mac Mouse Fix 3.0.2 har det vært [flere rapporter](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) om at Mac Mouse Fix periodisk deaktiverer og reaktiverer seg selv under rulling. Dette ble forårsaket av krasj i bakgrunnsappen 'Mac Mouse Fix Helper'. Denne oppdateringen forsøker å fikse disse krasjene, med følgende endringer:

- Rullemekanismen vil prøve å gjenopprette og fortsette å kjøre i stedet for å krasje, når den støter på grensetilfeller som ser ut til å ha ført til disse krasjene.
- Jeg endret måten uventede tilstander håndteres i appen mer generelt: I stedet for å alltid krasje umiddelbart, vil appen nå prøve å gjenopprette fra uventede tilstander i mange tilfeller.
    
    - Denne endringen bidrar til fiksene for rullekrasjene beskrevet ovenfor. Den kan også forhindre andre krasj.
  
Sidenotat: Jeg kunne aldri reprodusere disse krasjene på min maskin, og jeg er fortsatt ikke sikker på hva som forårsaket dem, men basert på rapportene jeg mottok, bør denne oppdateringen forhindre eventuelle krasj. Hvis du fortsatt opplever krasj under rulling eller hvis du *opplevde* krasj under 3.0.2, ville det være verdifullt om du delte din erfaring og diagnostiske data i GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Dette ville hjelpe meg å forstå problemet og forbedre Mac Mouse Fix. Takk!

### Løser rullehakking

I 3.0.2 gjorde jeg endringer i hvordan Mac Mouse Fix sender rullehendelser til systemet i et forsøk på å redusere rullehakking som sannsynligvis er forårsaket av problemer med Apples VSync-APIer.

Etter mer omfattende testing og tilbakemeldinger ser det imidlertid ut til at den nye mekanismen i 3.0.2 gjør rulling jevnere i noen scenarioer, men mer hakkete i andre. Spesielt i Firefox så det ut til å være merkbart verre. \
Totalt sett var det ikke klart at den nye mekanismen faktisk forbedret rullehakking generelt. Den kan også ha bidratt til rullekrasjene beskrevet ovenfor.

Derfor deaktiverte jeg den nye mekanismen og tilbakestilte VSync-mekanismen for rullehendelser til slik den var i Mac Mouse Fix 3.0.0 og 3.0.1.

Se GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) for mer info.

### Refusjon

Jeg beklager problemene relatert til rulleendringene i 3.0.1 og 3.0.2. Jeg undervurderte kraftig problemene som ville komme med det, og jeg var treg med å løse disse problemene. Jeg skal gjøre mitt beste for å lære av denne erfaringen og være mer forsiktig med slike endringer i fremtiden. Jeg vil også tilby alle berørte en refusjon. Bare klikk [her](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) hvis du er interessert.

### Smartere oppdateringsmekanisme

Disse endringene ble hentet fra Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) og [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Sjekk ut deres utgivelsesnotater for å lære mer om detaljene. Her er et sammendrag:

- Det er en ny, smartere mekanisme som bestemmer hvilken oppdatering som skal vises til brukeren.
- Byttet fra å bruke Sparkle 1.26.0 oppdateringsrammeverket til den nyeste Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- Vinduet som appen viser for å informere deg om at en ny versjon av Mac Mouse Fix er tilgjengelig, støtter nå JavaScript, som tillater penere formatering av oppdateringsnotatene.

### Andre forbedringer og feilrettinger

- Fikset et problem der appprisen og relatert info ble vist feil i 'Om'-fanen i noen tilfeller.
- Fikset et problem der mekanismen for synkronisering av jevn rulling med skjermens oppdateringsfrekvens ikke fungerte ordentlig ved bruk av flere skjermer.
- Mange mindre oppryddinger og forbedringer under panseret.

---

Sjekk også ut forrige utgivelse [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).