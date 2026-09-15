Mac Mouse Fix **2.2.5** har forbedringer i oppdateringsmekanismen, og er klar for macOS 15 Sequoia!

### Nytt Sparkle-oppdateringsrammeverk

Mac Mouse Fix bruker [Sparkle](https://sparkle-project.org/)-oppdateringsrammeverket for å gi en god oppdateringsopplevelse.

Med 2.2.5 bytter Mac Mouse Fix fra Sparkle 1.26.0 til den nyeste Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), som inneholder sikkerhetsfikser, lokaliseringsforbedringer og mer.

### Smartere oppdateringsmekanisme

Det er en ny mekanisme som bestemmer hvilken oppdatering som vises til brukeren. Oppførselen er endret på disse måtene:

1. Etter at du hopper over en **stor** oppdatering (som 2.2.5 -> 3.0.0), vil du fortsatt bli varslet om nye **mindre** oppdateringer (som 2.2.5 -> 2.2.6).
    - Dette lar deg enkelt bli på Mac Mouse Fix 2 mens du fortsatt mottar oppdateringer, som diskutert i GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. I stedet for å vise oppdateringen til den nyeste utgivelsen, vil Mac Mouse Fix nå vise deg oppdateringen til den første utgivelsen av den nyeste hovedversjonen.
    - Eksempel: Hvis du bruker MMF 2.2.5, og MMF 3.4.5 er den nyeste versjonen, vil appen nå vise deg den første versjonen av MMF 3 (3.0.0), i stedet for den nyeste versjonen (3.4.5). På denne måten ser alle MMF 2.2.5-brukere MMF 3.0.0-endringsloggen før de bytter til MMF 3.
    - Diskusjon:
        - Hovedmotivasjonen bak dette er at tidligere i år oppdaterte mange MMF 2-brukere direkte fra MMF 2 til MMF 3.0.1 eller 3.0.2. Siden de aldri så 3.0.0-endringsloggen, gikk de glipp av informasjon om prisendringene mellom MMF 2 og MMF 3 (MMF 3 er ikke lenger 100% gratis). Så da MMF 3 plutselig sa at de måtte betale for å fortsette å bruke appen, ble noen – forståelig nok – litt forvirret og opprørt.
        - Ulempe: Hvis du bare vil oppdatere til den nyeste versjonen, må du nå oppdatere to ganger i noen tilfeller. Dette er litt ineffektivt, men det bør fortsatt bare ta noen sekunder. Og siden dette gjør endringene mellom hovedversjoner mye mer transparente, synes jeg det er et fornuftig kompromiss.

### macOS 15 Sequoia-støtte

Mac Mouse Fix 2.2.5 vil fungere utmerket på den nye macOS 15 Sequoia – akkurat som 2.2.4 gjorde.

---

Sjekk også ut den forrige utgivelsen [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Hvis du har problemer med å aktivere Mac Mouse Fix etter oppdatering, vennligst sjekk ut ['Aktivere Mac Mouse Fix'-guiden](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*