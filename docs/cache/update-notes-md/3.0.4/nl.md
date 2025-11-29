Mac Mouse Fix **3.0.4** verbetert privacy, efficiëntie en betrouwbaarheid.\
Het introduceert een nieuw offline licentiesysteem en lost verschillende belangrijke bugs op.

### Verbeterde Privacy & Efficiëntie

3.0.4 introduceert een nieuw offline licentievalidatiesysteem dat internetverbindingen zoveel mogelijk minimaliseert.\
Dit verbetert de privacy en bespaart systeembronnen van je computer.\
Wanneer gelicentieerd, werkt de app nu 100% offline!

<details>
<summary><b>Klik hier voor meer details</b></summary>
Eerdere versies valideerden licenties online bij elke start, waardoor verbindingslogs mogelijk opgeslagen konden worden door servers van derden (GitHub en Gumroad). Het nieuwe systeem elimineert onnodige verbindingen – na de initiële licentieactivatie maakt het alleen verbinding met internet als lokale licentiegegevens beschadigd zijn.
<br><br>
Hoewel gebruikersgedrag nooit door mij persoonlijk is geregistreerd, maakte het vorige systeem het theoretisch mogelijk voor servers van derden om IP-adressen en verbindingstijden te loggen. Gumroad kon ook je licentiesleutel loggen en deze mogelijk correleren aan persoonlijke informatie die ze over je hebben vastgelegd toen je Mac Mouse Fix kocht.
<br><br>
Ik had deze subtiele privacykwesties niet overwogen toen ik het oorspronkelijke licentiesysteem bouwde, maar nu is Mac Mouse Fix zo privé en internetvrij als mogelijk!
<br><br>
Zie ook <a href=https://gumroad.com/privacy>Gumroad's privacybeleid</a> en deze <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub-opmerking</a> van mij.

</details>

### Bugfixes

- Een bug opgelost waarbij macOS soms vastliep bij het gebruik van 'Klik en Sleep' voor 'Spaces & Mission Control'.
- Een bug opgelost waarbij sneltoetsen in Systeeminstellingen soms werden verwijderd bij het gebruik van Mac Mouse Fix 'Klik'-acties zoals 'Mission Control'.
- [Een bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) opgelost waarbij de app soms stopte met werken en een melding toonde dat de 'Gratis dagen voorbij zijn' aan gebruikers die de app al hadden gekocht.
    - Als je deze bug hebt ervaren, bied ik mijn oprechte excuses aan voor het ongemak. Je kunt [hier een terugbetaling aanvragen](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- De manier verbeterd waarop de applicatie zijn hoofdvenster ophaalt, wat mogelijk een bug heeft opgelost waarbij het 'Activeer Licentie'-scherm soms niet verscheen.

### Gebruiksvriendelijkheidsverbeteringen

- Het onmogelijk gemaakt om spaties en regeleinden in te voeren in het tekstveld op het 'Activeer Licentie'-scherm.
    - Dit was een veelvoorkomend punt van verwarring, omdat het heel gemakkelijk is om per ongeluk een verborgen regeleinde te selecteren bij het kopiëren van je licentiesleutel uit Gumroad's e-mails.
- Deze update-notities worden automatisch vertaald voor niet-Engelstalige gebruikers (Mogelijk gemaakt door Claude). Ik hoop dat dit nuttig is! Als je problemen tegenkomt, laat het me weten. Dit is een eerste glimp van een nieuw vertaalsysteem dat ik het afgelopen jaar heb ontwikkeld.

### (Onofficiële) Ondersteuning voor macOS 10.14 Mojave Vervallen

Mac Mouse Fix 3 ondersteunt officieel macOS 11 Big Sur en later. Voor gebruikers die bereid waren enkele glitches en grafische problemen te accepteren, kon Mac Mouse Fix 3.0.3 en eerder echter nog steeds worden gebruikt op macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 laat die ondersteuning vallen en **vereist nu macOS 10.15 Catalina**. \
Mijn excuses voor eventueel ongemak hierdoor. Deze wijziging stelde me in staat om het verbeterde licentiesysteem te implementeren met moderne Swift-functies. Mojave-gebruikers kunnen Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) of de [nieuwste versie van Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest) blijven gebruiken. Ik hoop dat dit een goede oplossing is voor iedereen.

### Verbeteringen onder de motorkap

- Een nieuw 'MFDataClass'-systeem geïmplementeerd dat krachtigere datamodellering mogelijk maakt terwijl Mac Mouse Fix's configuratiebestand leesbaar en bewerkbaar blijft voor mensen.
- Ondersteuning gebouwd voor het toevoegen van andere betalingsplatforms dan Gumroad. Dus in de toekomst kunnen er gelokaliseerde checkouts zijn, en kan de app aan verschillende landen worden verkocht.
- Verbeterde logging waardoor ik effectievere "Debug Builds" kan maken voor gebruikers die moeilijk te reproduceren bugs ervaren.
- Veel andere kleine verbeteringen en opruimwerk.

*Bewerkt met uitstekende hulp van Claude.*

---

Bekijk ook de vorige release [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).