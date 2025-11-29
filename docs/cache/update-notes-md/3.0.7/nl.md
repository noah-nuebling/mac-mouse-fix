Mac Mouse Fix **3.0.7** lost verschillende belangrijke bugs op.

### Bugfixes

- App werkt weer op **oudere macOS-versies** (macOS 10.15 Catalina en macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 kon niet worden ingeschakeld onder die macOS-versies omdat de verbeterde 'Terug'- en 'Vooruit'-functie die in Mac Mouse Fix 3.0.6 werd geïntroduceerd, probeerde macOS-systeem-API's te gebruiken die niet beschikbaar waren.
- Problemen met **'Terug'- en 'Vooruit'-functie** opgelost
    - De verbeterde 'Terug'- en 'Vooruit'-functie die in Mac Mouse Fix 3.0.6 werd geïntroduceerd, zal nu altijd de 'main thread' gebruiken om macOS te vragen welke toetsaanslagen moeten worden gesimuleerd om terug en vooruit te gaan in de app die je gebruikt. \
    Dit kan crashes en onbetrouwbaar gedrag in sommige situaties voorkomen.
- Geprobeerd bug op te lossen waarbij **instellingen willekeurig werden gereset**  (Zie deze [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Ik heb de code die het configuratiebestand voor Mac Mouse Fix laadt herschreven om robuuster te zijn. Wanneer zeldzame macOS-bestandssysteemfouten optraden, kon de oude code soms ten onrechte denken dat het configuratiebestand corrupt was en het terugzetten naar de standaardinstellingen.
- Kans op bug waarbij **scrollen stopt met werken** verkleind     
     - Deze bug kan niet volledig worden opgelost zonder diepere wijzigingen, die waarschijnlijk andere problemen zouden veroorzaken. \
      Voor nu heb ik echter het tijdsvenster verkleind waarin een 'deadlock' kan optreden in het scrollsysteem, wat in ieder geval de kans op deze bug zou moeten verlagen. Dit maakt het scrollen ook iets efficiënter. 
    - Deze bug heeft vergelijkbare symptomen – maar volgens mij een andere onderliggende oorzaak – als de 'Scroll Stops Working Intermittently'-bug die in de vorige release 3.0.6 werd aangepakt.
    - (Bedankt aan Joonas voor de diagnostiek!) 

Bedankt iedereen voor het melden van de bugs! 

---

Bekijk ook de vorige release [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).