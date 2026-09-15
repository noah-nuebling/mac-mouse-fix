Mac Mouse Fix **3.0.7** løser flere viktige feil.

### Feilrettinger

- Appen fungerer igjen på **eldre macOS-versjoner** (macOS 10.15 Catalina og macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 kunne ikke aktiveres på disse macOS-versjonene fordi den forbedrede «Tilbake»- og «Fremover»-funksjonen introdusert i Mac Mouse Fix 3.0.6 forsøkte å bruke macOS system-APIer som ikke var tilgjengelige.
- Rettet problemer med **«Tilbake»- og «Fremover»**-funksjonen
    - Den forbedrede «Tilbake»- og «Fremover»-funksjonen introdusert i Mac Mouse Fix 3.0.6 vil nå alltid bruke «hovedtråden» for å spørre macOS om hvilke tastetrykk som skal simuleres for å gå tilbake og fremover i appen du bruker. \
    Dette kan forhindre krasj og upålitelig oppførsel i noen situasjoner.
- Forsøkt å fikse feil der **innstillinger ble tilfeldig tilbakestilt** (Se disse [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Jeg skrev om koden som laster konfigurasjonsfilen for Mac Mouse Fix for å gjøre den mer robust. Når sjeldne macOS-filsystemfeil oppstod, kunne den gamle koden noen ganger feilaktig tro at konfigurasjonsfilen var korrupt og tilbakestille den til standard.
- Redusert sjansen for en feil der **rulling slutter å fungere**     
     - Denne feilen kan ikke løses fullstendig uten dypere endringer, som sannsynligvis ville forårsake andre problemer. \
      Imidlertid har jeg foreløpig redusert tidsvinduet der en «deadlock» kan oppstå i rullesystemet, noe som i det minste bør redusere sjansen for å støte på denne feilen. Dette gjør også rullingen litt mer effektiv. 
    - Denne feilen har lignende symptomer – men jeg tror en annen underliggende årsak – som «Rulling slutter å fungere periodisk»-feilen som ble løst i forrige utgivelse 3.0.6.
    - (Takk til Joonas for diagnostikken!) 

Takk til alle som rapporterte feilene! 

---

Sjekk også ut forrige utgivelse [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).