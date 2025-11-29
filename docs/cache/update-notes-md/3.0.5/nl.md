Mac Mouse Fix **3.0.5** verhelpt verschillende bugs, verbetert de prestaties en voegt wat polish toe aan de app. \
Het is ook compatibel met macOS 26 Tahoe.

### Verbeterde Simulatie van Trackpad Scrollen

- Het scrollsysteem kan nu een twee-vinger tik op het trackpad simuleren om applicaties te laten stoppen met scrollen.
    - Dit verhelpt een probleem bij het draaien van iPhone- of iPad-apps, waarbij het scrollen vaak doorging nadat de gebruiker ervoor koos om te stoppen.
- Inconsistente simulatie van het optillen van vingers van het trackpad verholpen.
    - Dit kan in sommige situaties suboptimaal gedrag hebben veroorzaakt.



### macOS 26 Tahoe Compatibiliteit

Bij het draaien van de macOS 26 Tahoe Beta is de app nu bruikbaar en werkt het grootste deel van de UI correct.



### Prestatieverbetering

Verbeterde prestaties van het Klik en Sleep naar "Scroll & Navigeer" gebaar. \
In mijn tests is het CPU-gebruik met ~50% verminderd!

**Achtergrond**

Tijdens het "Scroll & Navigeer" gebaar tekent Mac Mouse Fix een nep-muiscursor in een transparant venster, terwijl de echte muiscursor op zijn plaats wordt vergrendeld. Dit zorgt ervoor dat je kunt blijven scrollen op het UI-element waar je mee begon te scrollen, ongeacht hoe ver je je muis beweegt.

De verbeterde prestaties werden bereikt door de standaard macOS event handling op dit transparante venster uit te schakelen, die toch niet werd gebruikt.





### Bugfixes

- Scrollgebeurtenissen van Wacom tekentabletten worden nu genegeerd.
    - Voorheen veroorzaakte Mac Mouse Fix grillig scrollen op Wacom-tablets, zoals gerapporteerd door @frenchie1980 in GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Bedankt!)
    
- Een bug verholpen waarbij de Swift Concurrency code, die werd geïntroduceerd als onderdeel van het nieuwe licentiesysteem in Mac Mouse Fix 3.0.4, niet op de juiste thread draaide.
    - Dit veroorzaakte crashes op macOS Tahoe, en het veroorzaakte waarschijnlijk ook andere sporadische bugs rondom licenties.
- Robuustheid van de code die offline licenties decodeert verbeterd.
    - Dit werkt een probleem in Apple's API's om waardoor offline licentievalidatie altijd faalde op mijn Intel Mac Mini. Ik neem aan dat dit op alle Intel Macs gebeurde, en dat dit de reden was waarom de "Gratis dagen zijn voorbij" bug (die al was aangepakt in 3.0.4) nog steeds voorkwam bij sommige mensen, zoals gerapporteerd door @toni20k5267 in GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Dank je!)
        - Als je de "Gratis dagen zijn voorbij" bug hebt ervaren, mijn excuses daarvoor! Je kunt een terugbetaling krijgen [hier](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### UX Verbeteringen

- Dialogen uitgeschakeld die stap-voor-stap oplossingen boden voor macOS bugs die gebruikers ervan weerhielden Mac Mouse Fix in te schakelen.
    - Deze problemen kwamen alleen voor op macOS 13 Ventura en 14 Sonoma. Nu verschijnen deze dialogen alleen op die macOS-versies waar ze relevant zijn.
    - De dialogen zijn ook iets moeilijker te activeren – voorheen verschenen ze soms in situaties waar ze niet erg behulpzaam waren.
    
- Een "Activeer Licentie" link direct toegevoegd aan de "Gratis dagen zijn voorbij" melding.
    - Dit maakt het activeren van een Mac Mouse Fix licentie nog probleemloozer!

### Visuele Verbeteringen

- Het uiterlijk van het "Software Update" venster licht verbeterd. Nu past het beter bij macOS 26 Tahoe.
    - Dit werd gedaan door het standaard uiterlijk van het "Sparkle 1.27.3" framework aan te passen, dat Mac Mouse Fix gebruikt om updates af te handelen.
- Probleem verholpen waarbij de tekst onderaan het Over-tabblad soms werd afgesneden in het Chinees, door het venster iets breder te maken.
- De tekst onderaan het Over-tabblad die licht uit het midden stond verholpen.
- Een bug verholpen die ervoor zorgde dat de ruimte onder de "Toetsenbordsneltoets..." optie op het Knoppen-tabblad te klein was.

### Onder-De-Motorkap Wijzigingen

- Afhankelijkheid van het "SnapKit" framework verwijderd.
    - Dit verlaagt de grootte van de app licht van 19,8 naar 19,5 MB.
- Diverse andere kleine verbeteringen in de codebase.

*Bewerkt met uitstekende hulp van Claude.*

---

Bekijk ook de vorige release [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).