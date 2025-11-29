Mac Mouse Fix **3.0.3** is klaar voor macOS 15 Sequoia. Het lost ook enkele stabiliteitsproblemen op en biedt verschillende kleine verbeteringen.

### macOS 15 Sequoia ondersteuning

De app werkt nu goed onder macOS 15 Sequoia!

- De meeste UI-animaties werkten niet onder macOS 15 Sequoia. Nu werkt alles weer goed!
- De broncode is nu te bouwen onder macOS 15 Sequoia. Voorheen waren er problemen met de Swift-compiler die het bouwen van de app verhinderden.

### Scroll-crashes aanpakken

Sinds Mac Mouse Fix 3.0.2 waren er [meerdere meldingen](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) van Mac Mouse Fix die zichzelf periodiek uitschakelde en opnieuw inschakelde tijdens het scrollen. Dit werd veroorzaakt door crashes van de 'Mac Mouse Fix Helper' achtergrond-app. Deze update probeert deze crashes op te lossen, met de volgende wijzigingen:

- Het scrollmechanisme zal proberen te herstellen en blijven draaien in plaats van te crashen, wanneer het de edge case tegenkomt die tot deze crashes lijkt te hebben geleid.
- Ik heb de manier veranderd waarop onverwachte situaties in de app worden afgehandeld: In plaats van altijd direct te crashen, zal de app nu in veel gevallen proberen te herstellen van onverwachte situaties.
    
    - Deze wijziging draagt bij aan de fixes voor de scroll-crashes die hierboven zijn beschreven. Het kan ook andere crashes voorkomen.

Opmerking: Ik kon deze crashes nooit reproduceren op mijn machine, en ik weet nog steeds niet zeker wat ze veroorzaakte, maar op basis van de meldingen die ik ontving, zou deze update crashes moeten voorkomen. Als je nog steeds crashes ervaart tijdens het scrollen of als je *wel* crashes ervaarde onder 3.0.2, zou het waardevol zijn als je je ervaring en diagnostische gegevens deelt in GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Dit zou me helpen het probleem te begrijpen en Mac Mouse Fix te verbeteren. Bedankt!

### Scroll-hapering aanpakken

In 3.0.2 heb ik wijzigingen aangebracht in hoe Mac Mouse Fix scroll-events naar het systeem stuurt in een poging om scroll-hapering te verminderen die waarschijnlijk werd veroorzaakt door problemen met Apple's VSync API's.

Na uitgebreider testen en feedback lijkt het er echter op dat het nieuwe mechanisme in 3.0.2 het scrollen in sommige scenario's vloeiender maakt, maar in andere juist haperender. Vooral in Firefox leek het merkbaar slechter te zijn. \
Over het algemeen was het niet duidelijk dat het nieuwe mechanisme scroll-hapering daadwerkelijk over de hele linie verbeterde. Ook kan het hebben bijgedragen aan de scroll-crashes die hierboven zijn beschreven.

Daarom heb ik het nieuwe mechanisme uitgeschakeld en het VSync-mechanisme voor scroll-events teruggedraaid naar hoe het was in Mac Mouse Fix 3.0.0 en 3.0.1.

Zie GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) voor meer informatie.

### Terugbetaling

Het spijt me voor de problemen met betrekking tot de scrollwijzigingen in 3.0.1 en 3.0.2. Ik heb de problemen die daarmee zouden komen enorm onderschat, en ik was traag met het aanpakken van deze problemen. Ik zal mijn best doen om van deze ervaring te leren en voorzichtiger te zijn met dergelijke wijzigingen in de toekomst. Ik wil ook iedereen die getroffen is een terugbetaling aanbieden. Klik gewoon [hier](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) als je geïnteresseerd bent.

### Slimmer update-mechanisme

Deze wijzigingen zijn overgenomen van Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) en [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Bekijk hun release notes voor meer details. Hier is een samenvatting:

- Er is een nieuw, slimmer mechanisme dat bepaalt welke update aan de gebruiker wordt getoond.
- Overgestapt van het Sparkle 1.26.0 update-framework naar de nieuwste Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- Het venster dat de app toont om je te informeren dat er een nieuwe versie van Mac Mouse Fix beschikbaar is, ondersteunt nu JavaScript, wat zorgt voor een mooiere opmaak van de update-notities.

### Andere verbeteringen & bugfixes

- Een probleem opgelost waarbij de app-prijs en gerelateerde informatie in sommige gevallen onjuist werden weergegeven op het 'Over'-tabblad.
- Een probleem opgelost waarbij het mechanisme voor het synchroniseren van het vloeiend scrollen met de verversingssnelheid van het scherm niet goed werkte bij het gebruik van meerdere schermen.
- Veel kleine opruimingen en verbeteringen onder de motorkap.

---

Bekijk ook de vorige release [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).