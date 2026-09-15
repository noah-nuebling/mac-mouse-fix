Sjekk også ut de **flotte forbedringene** introdusert i [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6)!


---

**3.0.0 Beta 7** bringer flere små forbedringer og feilrettinger. 

Her er alt som er nytt:

**Forbedringer**

- Lagt til **koreanske oversettelser**. Stor takk til @jeongtae! (Finn ham på [GitHub](https://github.com/jeongtae))
- Gjort **rulling** med alternativet 'Glathet: Høy' **enda glattere**, ved å bare endre hastigheten gradvis, i stedet for å ha plutselige hopp i rullehastigheten når du beveger rullehjulet. Dette burde gjøre rulling litt glattere og lettere å følge med øynene uten å gjøre ting mindre responsivt. Rulling med 'Glathet: Høy' bruker nå rundt 30% mer CPU, på min datamaskin gikk det fra 1,2% CPU-bruk ved kontinuerlig rulling til 1,6%. Så rulling er fortsatt svært effektivt og jeg håper dette ikke vil utgjøre noen forskjell for noen. Stor takk til [MOS](https://mos.caldis.me/), som inspirerte denne funksjonen og hvis 'Scroll Monitor' jeg brukte for å hjelpe med å implementere funksjonen.
- Mac Mouse Fix **håndterer nå knappeinput fra alle kilder**. Tidligere ville Mac Mouse Fix bare håndtere input fra mus den gjenkjente. Jeg tror dette kan hjelpe kompatibilitet med visse mus i spesielle tilfeller, som når du bruker en Hackintosh, men det vil også føre til at Mac Mouse Fix fanger opp kunstig genererte knappeinput fra andre apper, noe som kan føre til problemer i andre spesielle tilfeller. Gi meg beskjed hvis dette fører til problemer for deg, så vil jeg ta tak i det i fremtidige oppdateringer.
- Forbedret følelsen og finishen av 'Klikk og rull' for 'Skrivebord og Launchpad' og 'Klikk og rull' for 'Flytt mellom Spaces'-bevegelser.
- Tar nå hensyn til informasjonstettheten i et språk når **tiden varsler vises** beregnes. Før dette ville varsler bare være synlige i veldig kort tid på språk med høy informasjonstetthet som kinesisk eller koreansk.
- Aktivert **forskjellige bevegelser** for å flytte mellom **Spaces**, åpne **Mission Control**, eller åpne **App Exposé**. I Beta 6 gjorde jeg det slik at disse handlingene bare var tilgjengelige gjennom 'Klikk og dra'-bevegelsen - som et eksperiment for å se hvor mange som faktisk brydde seg om å kunne få tilgang til disse handlingene på andre måter. Det ser ut til at noen gjør det, så nå har jeg gjort det mulig igjen å få tilgang til disse handlingene gjennom et enkelt 'Klikk' på en knapp eller gjennom 'Klikk og rull'.
- Gjort det mulig å **rotere** gjennom en **Klikk og rull**-bevegelse.
- **Forbedret** måten **Styreflate-simulering**-alternativet fungerer på i noen scenarioer. For eksempel når du ruller horisontalt for å slette en melding i Mail, er retningen meldingen beveger seg nå invertert, noe jeg håper føles litt mer naturlig og konsistent for de fleste.
- Lagt til en funksjon for å **tilordne** til **Primærklikk** eller **Sekundærklikk**. Jeg implementerte dette fordi høyre museknapp på favorittmusen min gikk i stykker. Disse alternativene er skjult som standard. Du kan se dem ved å holde nede Tilvalg-tasten mens du velger en handling. 
  - Dette mangler for øyeblikket oversettelser for kinesisk og koreansk, så hvis du vil bidra med oversettelser for disse funksjonene, ville det vært veldig satt pris på!

**Feilrettinger**

- Fikset en feil der **retningen på 'Klikk og dra'** for 'Mission Control og Spaces' var **invertert** for folk som aldri har byttet alternativet 'Naturlig rulling' i Systeminnstillinger. Nå skal retningen på 'Klikk og dra'-bevegelser i Mac Mouse Fix alltid matche retningen på bevegelser på styreflaten eller Magic Mouse. Hvis du vil ha et separat alternativ for å invertere 'Klikk og dra'-retningen, i stedet for å la den følge Systeminnstillingene, gi meg beskjed.
- Fikset en feil der **gratisdagene** ville **telles opp for raskt** for noen brukere. Hvis du ble påvirket av dette, gi meg beskjed så skal jeg se hva jeg kan gjøre.
- Fikset et problem under macOS Sonoma der fanelinjen ikke ville vises riktig.
- Fikset hakkete oppførsel når du bruker 'macOS' rullehastighet mens du bruker 'Klikk og rull' for å åpne Launchpad.
- Fikset krasj der 'Mac Mouse Fix Helper'-appen (som kjører i bakgrunnen når Mac Mouse Fix er aktivert) noen ganger ville krasje når du tok opp en hurtigtast.
- Fikset en feil der Mac Mouse Fix ville krasje når den prøvde å fange opp kunstige hendelser generert av [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma)
- Fikset et problem der navnet på noen mus som vises i 'Gjenopprett standarder...'-dialogen ville inneholde produsenten to ganger. 
- Gjort det mindre sannsynlig at 'Klikk og dra' for 'Mission Control og Spaces' henger seg opp når datamaskinen er treg. 
- Rettet bruk av 'Force Touch' i UI-strenger der det skulle være 'Kraftklikk'.
- Fikset en feil som ville oppstå for visse konfigurasjoner, der åpning av Launchpad eller visning av skrivebordet gjennom 'Klikk og rull' ikke ville fungere hvis du slapp knappen mens overgangsanimasjonen fortsatt pågikk.


**Mer**

- Flere forbedringer under panseret, stabilitetsforbedringer, opprydding under panseret, og mer.

## Hvordan du kan hjelpe

Du kan hjelpe ved å dele dine **ideer**, **problemer** og **tilbakemeldinger**!

Det beste stedet å dele dine **ideer** og **problemer** er [Tilbakemeldingsassistenten](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Det beste stedet å gi **rask** ustrukturert tilbakemelding er [Tilbakemeldingsdiskusjonen](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Du kan også få tilgang til disse stedene fra appen på '**ⓘ Om**'-fanen.

**Takk** for at du hjelper til med å gjøre Mac Mouse Fix bedre! 😎:)