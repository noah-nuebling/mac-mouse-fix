Sjekk også ut de **kule endringene** introdusert i [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

**3.0.0 Beta 6** bringer dype optimaliseringer og finpuss, en omarbeiding av rulleinnstillingene, kinesiske oversettelser og mer!

Her er alt som er nytt:

## 1. Dype optimaliseringer

For denne betaen la jeg mye arbeid i å få den siste biten av ytelse ut av Mac Mouse Fix. Og nå er jeg glad for å kunngjøre at når du klikker på en museknapp i Beta 6, er det **2x** raskere sammenlignet med forrige beta! Og rulling er til og med **4x** raskere!

Med Beta 6 vil MMF også smart slå av deler av seg selv for å spare CPU og batteri så mye som mulig.

For eksempel, når du bruker en mus med 3 knapper, men du bare har satt opp handlinger for knapper som ikke finnes på musen din, som knapp 4 og 5, vil Mac Mouse Fix slutte å lytte til knappeinndata fra musen din helt. Det betyr 0% CPU-bruk når du klikker på en knapp på musen! Eller når rulleinnstillingene i MMF matcher systemet, vil Mac Mouse Fix slutte å lytte til inndata fra rullehjulet ditt helt. Det betyr 0% CPU-bruk når du ruller! Men hvis du setter opp Command (⌘)-Rull for å zoome-funksjonen, vil Mac Mouse Fix begynne å lytte til rullehjulinndata - men bare mens du holder nede Command (⌘)-tasten. Og så videre.
Så det er virkelig smart og vil bare bruke CPU når det må!

Dette betyr at MMF nå ikke bare er den kraftigste, brukervennligste og mest polerte musedriveren for Mac, den er også en av, om ikke den, mest optimaliserte og effektive!

## 2. Redusert appstørrelse

Med 16 MB er Beta 6 ca. 2x mindre enn Beta 5!

Dette er en bieffekt av å droppe støtte for eldre macOS-versjoner.

## 3. Droppet støtte for eldre macOS-versjoner

Jeg prøvde hardt å få MMF 3 til å kjøre ordentlig på macOS-versjoner før macOS 11 Big Sur. Men mengden arbeid for å få det til å føles polert viste seg å være overveldende, så jeg måtte gi opp det.

Fremover vil den tidligste offisielt støttede versjonen være macOS 11 Big Sur.

Appen vil fortsatt åpne på eldre versjoner, men det vil være visuelle og kanskje andre problemer. Appen vil ikke lenger åpne på macOS-versjoner før 10.14.4. Dette er det som lar oss krympe appstørrelsen med 2x siden 10.14.4 er den tidligste macOS-versjonen som leveres med moderne Swift-biblioteker (se "Swift ABI Stability"), noe som betyr at disse Swift-bibliotekene ikke lenger trenger å være inkludert i appen.

## 4. Rulleforbedringer

Beta 6 har mange forbedringer i konfigurasjonen og brukergrensesnittet til de nye rullesystemene introdusert i MMF 3.

### Brukergrensesnitt

- Kraftig forenklet og forkortet brukergrensesnitteksten på Rulle-fanen. De fleste omtaler av ordet "Rulle" har blitt fjernet siden det er underforstått av konteksten.
- Omarbeidet innstillingene for rullejevnhet for å være mye klarere og tillate noen ekstra alternativer. Nå kan du velge mellom en "Jevnhet" på "Av", "Vanlig" eller "Høy", som erstatter den gamle "med Treghet"-bryteren. Jeg tror dette er mye klarere, og det ga plass i brukergrensesnittet for det nye "Styreflatesimulering"-alternativet.
- Å slå av det nye "Styreflatesimulering"-alternativet deaktiverer gummibåndeffekten mens du ruller, det forhindrer også rulling mellom sider i Safari og andre apper, og mer. Mange har vært irritert over dette, spesielt de med frittspinnende rullehjul som finnes på noen Logitech-mus som MX Master, men andre liker det, så jeg bestemte meg for å gjøre det til et alternativ. Jeg håper presentasjonen av funksjonen er klar. Hvis du har noen forslag der, gi meg beskjed.
- Endret alternativet "Naturlig rulleretning" til "Reverser rulleretning". Dette betyr at innstillingen nå reverserer systemets rulleretning og er ikke lenger uavhengig av systemets rulleretning. Selv om dette uten tvil er en litt dårligere brukeropplevelse, lar denne nye måten å gjøre ting på oss implementere noen optimaliseringer, og det gjør det mer transparent for brukeren hvordan man helt slår av Mac Mouse Fix for rulling.
- Forbedret måten rulleinnstillingene samhandler med modifisert rulling i mange forskjellige kanttilfeller. F.eks. vil "Presisjon"-alternativet ikke lenger gjelde for "Klikk og rull" for "Skrivebord og Launchpad"-handlingen siden det er en hindring her i stedet for å være nyttig.
- Forbedret rullehastighet når du bruker "Klikk og rull" for "Skrivebord og Launchpad" eller "Zoom inn eller ut" og andre funksjoner.
- Fjernet ikke-fungerende lenke til systemets rullehastighetsinnstillinger på rulle-fanen som var til stede på macOS-versjoner før macOS 13.0 Ventura. Jeg kunne ikke finne en måte å få lenken til å fungere på, og det er ikke veldig viktig.

### Rullefølelse

- Forbedret animasjonskurve for "Vanlig jevnhet" (tidligere tilgjengelig ved å slå av "med Treghet"). Dette gjør at ting føles mer jevne og responsive.
- Forbedret følelsen av alle rullehastighetsinnstillingene. "Medium" hastighet og "Rask" hastighet er raskere. Det er mer separasjon mellom "Lav", "Medium" og "Høy" hastigheter. Hastighetsøkningen når du beveger rullehjulet raskere føles mer naturlig og komfortabel når du bruker "Presisjon"-alternativet.
- Måten rullehastigheten øker når du fortsetter å rulle i én retning vil føles mer naturlig og gradvis. Jeg bruker nye matematiske kurver for å modellere hastighetsøkningen. Hastighetsøkningen vil også være vanskeligere å utløse ved et uhell.
- Øker ikke lenger rullehastigheten når du fortsetter å rulle i én retning mens du bruker "macOS" rullehastighet.
- Begrenset rulleanimasjonstiden til et maksimum. Hvis rulleanimasjonen naturlig ville ta mer tid, vil den bli akselerert for å holde seg under maksimumstiden. På den måten vil rulling inn i sidekanten med et frittspinnende hjul ikke ha sideinnholdet til å bevege seg utenfor skjermen så lenge. Dette bør ikke påvirke normal rulling med et ikke-frittspinnende hjul.
- Forbedret noen interaksjoner rundt gummibåndeffekten når du ruller inn i en sidekant i Safari og andre apper.
- Fikset et problem der "Klikk og rull" og andre rullerelaterte funksjoner ikke fungerte ordentlig etter oppgradering fra en veldig gammel innstillingspanel-versjon av Mac Mouse Fix.
- Fikset et problem der enkeltpikselrullinger ble sendt med forsinkelse når du brukte "macOS" rullehastighet sammen med jevn rulling.
- Fikset en feil der rulling fortsatt var veldig rask etter å ha sluppet Swift Scroll-modifikatoren. Andre forbedringer rundt hvordan rullehastighet overføres fra tidligere rullebevegelser.
- Forbedret måten rullehastigheten øker med større skjermstørrelser

## 5. Notarisering

Fra og med 3.0.0 Beta 6 vil Mac Mouse Fix være "Notarisert". Det betyr ingen flere meldinger om at Mac Mouse Fix potensielt er "Skadelig programvare" når du åpner appen for første gang.

Å notarisere appen din koster $100 per år. Jeg var alltid imot dette, siden det føltes fiendtlig mot gratis og åpen kildekode-programvare som Mac Mouse Fix, og det føltes også som et farlig skritt mot at Apple kontrollerer og låser ned Mac-en slik de gjør med iOS. Men mangel på notarisering førte til ganske alvorlige problemer, inkludert [flere situasjoner](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) der ingen kunne bruke appen lenger før jeg ga ut en ny versjon. Siden Mac Mouse Fix vil bli monetisert nå, tenkte jeg at det endelig var passende å notarisere appen for en enklere og mer stabil brukeropplevelse.

## 6. Kinesiske oversettelser

Mac Mouse Fix er nå tilgjengelig på kinesisk!
Mer spesifikt er den tilgjengelig på:

- Kinesisk, tradisjonell
- Kinesisk, forenklet
- Kinesisk (Hong Kong)

Stor takk til @groverlynn for å ha levert alle disse oversettelsene samt for å oppdatere dem gjennom betaene og kommunisere med meg. Se hans pull request her: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Alt annet

Bortsett fra endringene listet ovenfor har Beta 6 også mange mindre forbedringer.

- Fjernet flere alternativer fra "Klikk", "Klikk og hold" og "Klikk og rull"-handlingene fordi jeg syntes de var overflødige siden samme funksjonalitet kan oppnås på andre måter, og siden dette rydder opp i menyene mye. Vil bringe tilbake disse alternativene hvis folk klager. Så hvis du savner disse alternativene - vennligst klag.
- Klikk og dra-retning vil nå matche styreflate-sveiperetning selv når "Naturlig rulling" er slått av under Systeminnstillinger > Styreflate. Før ville Klikk og dra alltid oppføre seg som å sveipe på styreflaten med "Naturlig rulling" slått *på*.
- Fikset et problem der markørene ville forsvinne og deretter dukke opp et annet sted når du brukte en "Klikk og dra"-handling under et skjermopptak eller når du brukte DisplayLink-programvaren.
- Fikset sentrering av "+" i "+"-feltet på Knapper-fanen
- Flere visuelle forbedringer på knapper-fanen. Fargepaletten til "+"-feltet og handlingstabellen har blitt omarbeidet for å se riktig ut når du bruker macOS' "Tillat bakgrunnsfargelegging i vinduer"-alternativ. Kantene på handlingstabellen har nå en gjennomsiktig farge som ser mer dynamisk ut og tilpasser seg omgivelsene.
- Gjort det slik at når du legger til mange handlinger i handlingstabellen og Mac Mouse Fix-vinduet vokser, vil det vokse nøyaktig så stort som skjermen (eller som skjermen minus dokken hvis du ikke har dokk-skjuling aktivert) og deretter stoppe. Når du legger til enda flere handlinger, vil handlingstabellen begynne å rulle.
- Denne betaen støtter nå en ny utsjekking der du kan kjøpe en lisens i amerikanske dollar som annonsert. Før kunne du bare kjøpe en lisens i euro. De gamle euro-lisensene vil selvfølgelig fortsatt støttes.
- Fikset et problem der momentumrulling noen ganger ikke ble startet når du brukte "Rull og naviger"-funksjonen.
- Når Mac Mouse Fix-vinduet endrer størrelse under en fanebytte, vil det nå reposisjonere seg slik at det ikke overlapper med dokken
- Fikset flimring på noen brukergrensesnittelementer når du bytter fra Knapper-fanen til en annen fane
- Forbedret utseendet på animasjonen som "+"-feltet spiller etter å ha registrert en inndata. Spesielt på macOS-versjoner før Ventura, der skyggen til "+"-feltet ville se feilaktig ut under animasjonen.
- Deaktivert varsler som lister opp flere knapper som har blitt fanget/ikke lenger fanges av Mac Mouse Fix, som ville dukke opp når du startet appen for første gang eller når du lastet en forhåndsinnstilling. Jeg syntes disse meldingene var distraherende og litt overveldende og ikke veldig nyttige i disse kontekstene.
- Omarbeidet skjermen for å gi tilgangstillatelse. Den vil nå vise informasjon om hvorfor Mac Mouse Fix trenger tilgangstillatelse inline i stedet for å lenke til nettsiden, og den er litt klarere og har et mer visuelt tiltalende oppsett.
- Oppdatert Anerkjennelser-lenken på Om-fanen.
- Forbedret feilmeldinger når Mac Mouse Fix ikke kan aktiveres fordi det er en annen versjon til stede på systemet. Meldingen vil nå vises i et flytende varselvindu som alltid holder seg på toppen av andre vinduer til det avvises, i stedet for en Toast-varsling som forsvinner når du klikker hvor som helst. Dette bør gjøre det lettere å følge de foreslåtte løsningstrinnene.
- Fikset noen problemer med markdown-gjengivelse på macOS-versjoner før Ventura. MMF vil nå bruke en tilpasset markdown-gjengivelsesløsning for alle macOS-versjoner, inkludert Ventura. Før brukte vi en system-API introdusert i Ventura, men det førte til inkonsekvenser. Markdown brukes til å legge til lenker og fremheving av tekst i hele brukergrensesnittet.
- Polert interaksjonene rundt aktivering av tilgangstillatelse.
- Fikset et problem der appvinduet noen ganger ville åpne uten å vise noe innhold før du byttet til en av fanene.
- Fikset et problem med "+"-feltet der du noen ganger ikke kunne legge til en ny handling selv om det viste en hover-effekt som indikerte at du kan legge inn en handling.
- Fikset en deadlock og flere andre små problemer som noen ganger ville skje når du flyttet musepekeren inne i "+"-feltet
- Fikset et problem der en popover som vises på Knapper-fanen når musen din ikke ser ut til å passe til de gjeldende knappeinnstillingene, noen ganger ville ha all tekst i fet skrift.
- Oppdatert alle omtaler av den gamle MIT-lisensen til den nye MMF-lisensen. Nye filer opprettet for prosjektet vil nå inneholde en autogenerert header som nevner MMF-lisensen.
- Gjort det slik at bytte til Knapper-fanen aktiverer MMF for rulling. Ellers kunne du ikke registrere Klikk og rull-bevegelser.
- Fikset noen problemer der knappenavn ikke ble vist riktig i handlingstabellen i noen situasjoner.
- Fikset feil der prøveseksjonen på Om-skjermen ville se feilaktig ut når du åpnet appen og deretter byttet til prøvefanen etter at prøveperioden utløp.
- Fikset en feil der Aktiver lisens-lenken i prøveseksjonen på Om-fanen noen ganger ikke reagerte på klikk.
- Fikset en minnelekkasje når du brukte "Klikk og dra" for "Spaces og Mission Control"-funksjonen.
- Aktivert Hardened runtime på hoved-Mac Mouse Fix-appen, som forbedrer sikkerheten
- Mye koderydding, prosjektrestrukturering
- Flere andre krasjer fikset
- Flere minnelekkasjer fikset
- Diverse små justeringer av brukergrensesnittstrenger
- Omarbeidinger av flere interne systemer forbedret også robusthet og oppførsel i kanttilfeller

## 8. Hvordan du kan hjelpe

Du kan hjelpe ved å dele dine **ideer**, **problemer** og **tilbakemeldinger**!

Det beste stedet å dele dine **ideer** og **problemer** er [Tilbakemeldingsassistenten](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Det beste stedet å gi **rask** ustrukturert tilbakemelding er [Tilbakemeldingsdiskusjonen](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Du kan også få tilgang til disse stedene fra appen på "**ⓘ Om**"-fanen.

**Takk** for at du hjelper til med å gjøre Mac Mouse Fix så bra som mulig! 🙌:)