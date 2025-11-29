Mac Mouse Fix **3.0.6** maakt de 'Terug' en 'Vooruit' functie compatibel met meer apps.
Het lost ook verschillende bugs en problemen op.

### Verbeterde 'Terug' en 'Vooruit' Functie

De 'Terug' en 'Vooruit' muisknoptoewijzingen **werken nu in meer apps**, waaronder:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed, en andere code-editors
- Veel ingebouwde Apple-apps zoals Voorbeeld, Notities, Systeeminstellingen, App Store en Muziek
- Adobe Acrobat
- Zotero
- En meer!

De implementatie is geïnspireerd door de geweldige 'Universal Back and Forward' functie in [LinearMouse](https://github.com/linearmouse/linearmouse). Het zou alle apps moeten ondersteunen die LinearMouse ondersteunt. \
Bovendien ondersteunt het enkele apps die normaal gesproken sneltoetsen nodig hebben om terug en vooruit te gaan, zoals Systeeminstellingen, App Store, Apple Notities en Adobe Acrobat. Mac Mouse Fix detecteert nu deze apps en simuleert de juiste sneltoetsen.

Elke app die ooit is [aangevraagd in een GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) zou nu ondersteund moeten worden! (Bedankt voor de feedback!) \
Als je apps vindt die nog niet werken, laat het me weten in een [functieverzoek](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Oplossing voor de 'Scrollen Stopt Af en Toe' Bug

Sommige gebruikers ondervonden een [probleem](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) waarbij **vloeiend scrollen willekeurig stopt met werken**.

Hoewel ik het probleem zelf nooit heb kunnen reproduceren, heb ik een mogelijke oplossing geïmplementeerd:

De app zal nu meerdere keren opnieuw proberen wanneer het instellen van de beeldschermsynchronisatie mislukt. \
Als het na meerdere pogingen nog steeds niet werkt, zal de app:

- Het 'Mac Mouse Fix Helper' achtergrondproces herstarten, wat het probleem mogelijk oplost
- Een crashrapport genereren, wat kan helpen bij het diagnosticeren van de bug

Ik hoop dat het probleem nu is opgelost! Zo niet, laat het me weten in een [bugrapport](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) of via [e-mail](http://redirect.macmousefix.com/?target=mailto-noah).



### Verbeterd Gedrag van Vrij Draaiend Scrollwiel

Mac Mouse Fix zal **het scrollen niet langer versnellen** wanneer je het scrollwiel vrij laat draaien op de MX Master muis. (Of een andere muis met een vrij draaiend scrollwiel.)

Hoewel deze 'scrollversnelling' functie nuttig is bij gewone scrollwielen, kan het bij een vrij draaiend scrollwiel de controle bemoeilijken.

**Let op:** Mac Mouse Fix is momenteel niet volledig compatibel met de meeste Logitech-muizen, inclusief de MX Master. Ik ben van plan volledige ondersteuning toe te voegen, maar dat zal waarschijnlijk even duren. In de tussentijd is de beste third-party driver met Logitech-ondersteuning die ik ken [SteerMouse](https://plentycom.jp/en/steermouse/).





### Bugfixes

- Een probleem opgelost waarbij Mac Mouse Fix soms sneltoetsen opnieuw inschakelde die eerder waren uitgeschakeld in Systeeminstellingen  
- Een crash opgelost bij het klikken op 'Activeer Licentie' 
- Een crash opgelost bij het klikken op 'Annuleer' direct na het klikken op 'Activeer Licentie' (Bedankt voor de melding, Ali!)
- Crashes opgelost bij pogingen om Mac Mouse Fix te gebruiken terwijl er geen beeldscherm is aangesloten op je Mac 
- Een geheugenlek en enkele andere onderliggende problemen opgelost bij het wisselen tussen tabbladen in de app 

### Visuele Verbeteringen

- Een probleem opgelost waarbij het Over-tabblad soms te hoog was, wat werd geïntroduceerd in [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Tekst op de 'Gratis dagen zijn voorbij' melding wordt niet langer afgesneden in het Chinees
- Een visuele glitch opgelost op de schaduw van het '+' veld na het opnemen van een invoer
- Een zeldzame glitch opgelost waarbij de plaatshouder tekst op het 'Voer Je Licentiesleutel In' scherm niet gecentreerd verscheen
- Een probleem opgelost waarbij sommige symbolen in de app de verkeerde kleur hadden na het wisselen tussen donkere/lichte modus

### Overige Verbeteringen

- Enkele animaties, zoals de tabbladwisselanimatie, iets efficiënter gemaakt  
- Touch Bar tekstcompletering uitgeschakeld op het 'Voer Je Licentiesleutel In' scherm 
- Diverse kleinere onderliggende verbeteringen

*Bewerkt met uitstekende hulp van Claude.*

---

Bekijk ook de vorige release [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).