Mac Mouse Fix **3.0.1** brengt verschillende bugfixes en verbeteringen, samen met een **nieuwe taal**!

### Vietnamese is toegevoegd!

Mac Mouse Fix is nu beschikbaar in 🇻🇳 Vietnamees. Grote dank aan @nghlt [op GitHub](https://GitHub.com/nghlt)!

### Bugfixes

- Mac Mouse Fix werkt nu correct met **Snel gebruiker wisselen**!
  - Snel gebruiker wisselen is wanneer je inlogt op een tweede macOS-account zonder uit te loggen bij het eerste account.
  - Voor deze update stopte het scrollen met werken na een snelle gebruikerswissel. Nu zou alles correct moeten werken.
- Een kleine bug opgelost waarbij de layout van het tabblad Knoppen te breed was na het eerste gebruik van Mac Mouse Fix.
- Het '+' veld werkt nu betrouwbaarder bij het snel achter elkaar toevoegen van meerdere Acties.
- Een obscure crash opgelost die werd gemeld door @V-Coba in Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Andere verbeteringen

- **Scrollen voelt responsiever** bij gebruik van de 'Vloeiendheid: Normaal' instelling.
  - De animatiesnelheid wordt nu sneller naarmate je het scrollwiel sneller beweegt. Hierdoor voelt het responsiever aan wanneer je snel scrolt, terwijl het net zo vloeiend blijft wanneer je langzaam scrolt.

- De **scroll-snelheidsversnelling** is stabieler en voorspelbaarder gemaakt.
- Een mechanisme geïmplementeerd om je **instellingen te behouden** wanneer je update naar een nieuwe Mac Mouse Fix versie.
  - Voorheen werden alle instellingen gereset na een update naar een nieuwe versie als de structuur van de instellingen was veranderd. Nu zal Mac Mouse Fix proberen de structuur van je instellingen te upgraden en je voorkeuren te behouden.
  - Dit werkt momenteel alleen bij updates van 3.0.0 naar 3.0.1. Als je update vanaf een oudere versie dan 3.0.0, of als je _downgradet_ van 3.0.1 _naar_ een eerdere versie, worden je instellingen nog steeds gereset.
- De layout van het tabblad Knoppen past zich nu beter aan aan verschillende talen.
- Verbeteringen aan de [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) en andere documenten.
- Verbeterde lokalisatiesystemen. De vertaalbestanden worden nu automatisch opgeschoond en geanalyseerd op mogelijke problemen. Er is een nieuwe [Localization Guide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) die automatisch gedetecteerde problemen toont samen met andere nuttige informatie en instructies voor mensen die willen helpen met het vertalen van Mac Mouse Fix. Afhankelijkheid van de [BartyCrouch](https://github.com/FlineDev/BartyCrouch) tool verwijderd die eerder werd gebruikt voor een deel van deze functionaliteit.
- Verschillende UI-teksten in het Engels en Duits verbeterd.
- Veel opschoning en verbeteringen onder de motorkap.

---

Bekijk ook de release notes van [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - de grootste update voor Mac Mouse Fix tot nu toe!