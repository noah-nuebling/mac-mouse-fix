Mac Mouse Fix **3.0.7** åtgärdar flera viktiga buggar.

### Buggfixar

- Appen fungerar igen på **äldre macOS-versioner** (macOS 10.15 Catalina och macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 kunde inte aktiveras under dessa macOS-versioner eftersom den förbättrade 'Bakåt'- och 'Framåt'-funktionen som introducerades i Mac Mouse Fix 3.0.6 försökte använda macOS-system-API:er som inte var tillgängliga.
- Fixade problem med **'Bakåt'- och 'Framåt'**-funktionen
    - Den förbättrade 'Bakåt'- och 'Framåt'-funktionen som introducerades i Mac Mouse Fix 3.0.6 kommer nu alltid att använda 'huvudtråden' för att fråga macOS om vilka tangenttryckningar som ska simuleras för att gå bakåt och framåt i appen du använder. \
    Detta kan förhindra krascher och opålitligt beteende i vissa situationer.
- Försökte fixa bugg där **inställningar slumpmässigt återställdes**  (Se dessa [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Jag skrev om koden som laddar konfigurationsfilen för Mac Mouse Fix för att vara mer robust. När sällsynta macOS-filsystemfel inträffade kunde den gamla koden ibland felaktigt tro att konfigurationsfilen var korrupt och återställa den till standard.
- Minskade risken för en bugg där **scrollning slutar fungera**     
     - Denna bugg kan inte lösas helt utan djupare ändringar, vilket troligen skulle orsaka andra problem. \
      Men för tillfället minskade jag tidsfönstret där ett 'dödläge' kan uppstå i scrollsystemet, vilket åtminstone borde sänka risken att stöta på denna bugg. Detta gör också scrollningen något mer effektiv. 
    - Denna bugg har liknande symptom – men jag tror en annan underliggande orsak – som 'Scroll Stops Working Intermittently'-buggen som åtgärdades i den senaste versionen 3.0.6.
    - (Tack till Joonas för diagnostiken!) 

Tack alla för att ni rapporterade buggarna! 

---

Kolla även in den tidigare versionen [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).