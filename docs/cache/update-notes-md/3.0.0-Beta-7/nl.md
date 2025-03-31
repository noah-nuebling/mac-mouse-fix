Bekijk ook de **handige verbeteringen** die zijn geïntroduceerd in [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6)!


---

**3.0.0 Beta 7** brengt verschillende kleine verbeteringen en bugfixes.

Hier is alles wat nieuw is:

**Verbeteringen**

- **Koreaanse vertalingen** toegevoegd. Grote dank aan @jeongtae! (Vind hem op [GitHub](https://github.com/jeongtae))
- **Scrollen** met de 'Vloeiendheid: Hoog' optie **nog vloeiender** gemaakt door de snelheid alleen geleidelijk te veranderen, in plaats van plotselinge sprongen in de scrollsnelheid tijdens het bewegen van het scrollwiel. Dit zou het scrollen wat vloeiender en makkelijker te volgen moeten maken met je ogen zonder dat het minder responsief wordt. Scrollen met 'Vloeiendheid: Hoog' gebruikt nu ongeveer 30% meer CPU, op mijn computer ging het van 1.2% CPU-gebruik bij continu scrollen naar 1.6%. Scrollen blijft dus zeer efficiënt en ik hoop dat dit voor niemand een verschil zal maken. Grote dank aan [MOS](https://mos.caldis.me/), dat de inspiratie was voor deze functie en waarvan ik de 'Scroll Monitor' heb gebruikt om de functie te implementeren.
- Mac Mouse Fix **verwerkt nu knopinvoer van alle bronnen**. Voorheen verwerkte Mac Mouse Fix alleen invoer van muizen die het herkende. Ik denk dat dit de compatibiliteit met bepaalde muizen in randgevallen kan verbeteren, bijvoorbeeld bij gebruik van een Hackintosh, maar het zorgt er ook voor dat Mac Mouse Fix kunstmatig gegenereerde knopinvoer van andere apps oppikt, wat in andere randgevallen tot problemen kan leiden. Laat het me weten als dit problemen voor je veroorzaakt, dan zal ik dat in toekomstige updates aanpakken.
- Het gevoel en de afwerking verfijnd van de 'Klik en Scroll' voor 'Bureaublad & Launchpad' en 'Klik en Scroll' voor 'Tussen Spaces bewegen' gebaren.
- Er wordt nu rekening gehouden met de informatiedichtheid van een taal bij het berekenen van de **tijd dat meldingen worden getoond**. Voorheen bleven meldingen maar heel kort zichtbaar in talen met hoge informatiedichtheid zoals Chinees of Koreaans.
- **Verschillende gebaren** mogelijk gemaakt om tussen **Spaces** te bewegen, **Mission Control** te openen, of **App Exposé** te openen. In Beta 6 had ik deze acties alleen beschikbaar gemaakt via het 'Klik en Sleep' gebaar - als experiment om te zien hoeveel mensen het echt belangrijk vonden om deze acties op andere manieren te kunnen gebruiken. Het lijkt erop dat sommigen dat wel willen, dus nu is het weer mogelijk om deze acties te gebruiken via een simpele 'Klik' van een knop of via 'Klik en Scroll'.
- Mogelijk gemaakt om te **Roteren** via een **Klik en Scroll** gebaar.
- De werking van de **Trackpad Simulatie** optie **verbeterd** in sommige scenario's. Bijvoorbeeld bij horizontaal scrollen om een bericht in Mail te verwijderen, is de richting waarin het bericht beweegt nu omgekeerd, wat hopelijk voor de meeste mensen natuurlijker en consistenter aanvoelt.
- Een functie toegevoegd om te **herkoppelen** naar **Primaire Klik** of **Secundaire Klik**. Ik heb dit geïmplementeerd omdat de rechtermuisknop op mijn favoriete muis kapot ging. Deze opties zijn standaard verborgen. Je kunt ze zien door de Option-toets ingedrukt te houden tijdens het selecteren van een actie.
  - Dit mist momenteel vertalingen voor Chinees en Koreaans, dus als je vertalingen voor deze functies wilt bijdragen zou dat zeer gewaardeerd worden!

**Bugfixes**

- Een bug opgelost waarbij de **richting van 'Klik en Sleep'** voor 'Mission Control & Spaces' **omgekeerd** was voor mensen die nooit de 'Natuurlijk scrollen' optie in Systeeminstellingen hebben omgeschakeld. Nu zou de richting van 'Klik en Sleep' gebaren in Mac Mouse Fix altijd moeten overeenkomen met de richting van gebaren op je Trackpad of Magic Mouse. Als je een aparte optie wilt voor het omkeren van de 'Klik en Sleep' richting, in plaats van dat het de Systeeminstellingen volgt, laat het me weten.
- Een bug opgelost waarbij de **gratis dagen** voor sommige gebruikers **te snel optelden**. Als je hier last van had, laat het me weten en ik zal kijken wat ik kan doen.
- Een probleem opgelost onder macOS Sonoma waarbij de tabbalk niet correct werd weergegeven.
- Schokkerigheid opgelost bij gebruik van 'macOS' scrollsnelheid tijdens 'Klik en Scroll' om Launchpad te openen.
- Crash opgelost waarbij de 'Mac Mouse Fix Helper' app (die op de achtergrond draait wanneer Mac Mouse Fix is ingeschakeld) soms zou crashen bij het opnemen van een sneltoets.
- Een bug opgelost waarbij Mac Mouse Fix zou crashen bij het oppikken van kunstmatige events gegenereerd door [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma)
- Een probleem opgelost waarbij de naam voor sommige muizen in de 'Standaardinstellingen herstellen...' dialoog de fabrikant twee keer bevatte.
- De kans verkleind dat 'Klik en Sleep' voor 'Mission Control & Spaces' vastloopt wanneer de computer traag is.
- Gebruik van 'Force Touch' in UI-teksten gecorrigeerd waar het 'Force click' moet zijn.
- Een bug opgelost die zou optreden bij bepaalde configuraties, waarbij het openen van Launchpad of het tonen van het Bureaublad via 'Klik en Scroll' niet zou werken als je de knop losliet terwijl de overgangsanimatie nog bezig was.

**Meer**

- Verschillende verbeteringen onder de motorkap, stabiliteitsverbeteringen, opschoning onder de motorkap, en meer.

## Hoe Je Kunt Helpen

Je kunt helpen door je **ideeën**, **problemen** en **feedback** te delen!

De beste plek om je **ideeën** en **problemen** te delen is de [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
De beste plek om **snelle** ongestructureerde feedback te geven is de [Feedback Discussie](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Je kunt deze plekken ook bereiken vanuit de app op het '**ⓘ Over**' tabblad.

**Bedankt** voor je hulp om Mac Mouse Fix beter te maken! 😎:)