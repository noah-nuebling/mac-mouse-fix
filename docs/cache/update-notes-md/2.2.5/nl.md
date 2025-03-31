Mac Mouse Fix **2.2.5** bevat verbeteringen aan het update-mechanisme en is klaar voor macOS 15 Sequoia!

### Nieuw Sparkle update framework

Mac Mouse Fix gebruikt het [Sparkle](https://sparkle-project.org/) update framework om een geweldige update-ervaring te bieden.

Met 2.2.5 stapt Mac Mouse Fix over van Sparkle 1.26.0 naar de nieuwste Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), met beveiligingsverbeteringen, lokalisatie-updates en meer.

### Slimmer update-mechanisme

Er is een nieuw mechanisme dat bepaalt welke update aan de gebruiker wordt getoond. Het gedrag is op deze manieren veranderd:

1. Nadat je een **grote** update overslaat (zoals 2.2.5 -> 3.0.0), krijg je nog steeds meldingen over nieuwe **kleine** updates (zoals 2.2.5 -> 2.2.6).
    - Hierdoor kun je gemakkelijk bij Mac Mouse Fix 2 blijven terwijl je updates blijft ontvangen, zoals besproken in GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. In plaats van de update naar de nieuwste versie te tonen, zal Mac Mouse Fix nu de update naar de eerste release van de nieuwste hoofdversie tonen.
    - Voorbeeld: Als je MMF 2.2.5 gebruikt, en MMF 3.4.5 de nieuwste versie is, zal de app nu de eerste versie van MMF 3 (3.0.0) tonen, in plaats van de nieuwste versie (3.4.5). Zo zien alle MMF 2.2.5 gebruikers de MMF 3.0.0 changelog voordat ze overstappen naar MMF 3.
    - Toelichting:
        - De belangrijkste reden hiervoor is dat eerder dit jaar veel MMF 2 gebruikers direct van MMF 2 naar MMF 3.0.1 of 3.0.2 updateten. Omdat ze nooit de 3.0.0 changelog zagen, misten ze informatie over de prijswijzigingen tussen MMF 2 en MMF 3 (MMF 3 is niet meer 100% gratis). Dus toen MMF 3 plotseling aangaf dat ze moesten betalen om de app te blijven gebruiken, waren sommigen - begrijpelijk - wat verward en ontstemd.
        - Nadeel: Als je gewoon naar de nieuwste versie wilt updaten, moet je nu in sommige gevallen twee keer updaten. Dit is iets minder efficiënt, maar het zou nog steeds maar een paar seconden moeten duren. En omdat dit de veranderingen tussen hoofdversies veel transparanter maakt, denk ik dat het een verstandige afweging is.

### macOS 15 Sequoia ondersteuning

Mac Mouse Fix 2.2.5 werkt uitstekend op het nieuwe macOS 15 Sequoia - net zoals 2.2.4 dat deed.

---

Bekijk ook de vorige release [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Als je problemen hebt met het inschakelen van Mac Mouse Fix na het updaten, bekijk dan de ['Mac Mouse Fix inschakelen' Handleiding](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*