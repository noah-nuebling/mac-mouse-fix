Mac Mouse Fix **3.0.1** bringer flere feilrettinger og forbedringer, sammen med et **nytt språk**!

### Vietnamesisk ble lagt til!

Mac Mouse Fix er nå tilgjengelig på 🇻🇳 vietnamesisk. Stor takk til @nghlt [på GitHub](https://GitHub.com/nghlt)!


### Feilrettinger

- Mac Mouse Fix fungerer nå ordentlig med **Rask brukerbytte**!
  - Rask brukerbytte er når du logger inn på en annen macOS-konto uten å logge ut av den første kontoen. 
  - Før denne oppdateringen sluttet rulling å fungere etter et raskt brukerbytte. Nå skal alt fungere korrekt.
- Rettet en liten feil der oppsettet av Knapper-fanen var for bredt etter å ha startet Mac Mouse Fix for første gang. 
- Gjorde '+'-feltet mer pålitelig når du legger til flere handlinger raskt etter hverandre. 
- Rettet en obskur krasj rapportert av @V-Coba i sak [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Andre forbedringer

- **Rulling føles mer responsiv** når du bruker innstillingen 'Glathet: Vanlig'.
  - Animasjonshastigheten blir nå raskere jo raskere du beveger rullehjulet. På den måten føles det mer responsivt når du ruller raskt, samtidig som det føles like glatt når du ruller sakte.
  
- Gjorde **rullehastighetakselerasjonen** mer stabil og forutsigbar. 
- Implementerte en mekanisme for å **beholde innstillingene dine** når du oppdaterer til en ny Mac Mouse Fix-versjon.
  - Tidligere ville Mac Mouse Fix tilbakestille alle innstillingene dine etter oppdatering til en ny versjon, hvis strukturen på innstillingene endret seg. Nå vil Mac Mouse Fix forsøke å oppgradere strukturen på innstillingene dine og beholde preferansene dine. 
  - Foreløpig fungerer dette bare når du oppdaterer fra 3.0.0 til 3.0.1. Hvis du oppdaterer fra en eldre versjon enn 3.0.0, eller hvis du _nedgraderer_ fra 3.0.1 _til_ en tidligere versjon, vil innstillingene dine fortsatt bli tilbakestilt. 
- Oppsettet av Knapper-fanen tilpasser nå bredden bedre til forskjellige språk. 
- Forbedringer av [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) og andre dokumenter.
- Forbedrede lokaliseringssystemer. Oversettelsesfilene blir nå automatisk ryddet opp og analysert for potensielle problemer. Det er en ny [Lokaliseringsguide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) som viser automatisk oppdagede problemer sammen med annen nyttig informasjon og instruksjoner for folk som vil hjelpe til med å oversette Mac Mouse Fix. Fjernet avhengighet av [BartyCrouch](https://github.com/FlineDev/BartyCrouch)-verktøyet som tidligere ble brukt for å få noe av denne funksjonaliteten.
- Forbedret flere UI-tekster på engelsk og tysk.
- Mye opprydding og forbedringer under panseret.

---

Sjekk også ut utgivelsesnotatene for [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - den største oppdateringen til Mac Mouse Fix så langt!