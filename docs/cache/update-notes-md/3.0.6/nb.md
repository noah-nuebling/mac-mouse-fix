


Mac Mouse Fix **3.0.6** gjør «Tilbake»- og «Fremover»-funksjonen kompatibel med flere apper.
Den løser også flere feil og problemer.

### Forbedret «Tilbake»- og «Fremover»-funksjon

Museknapp-tilordningene for «Tilbake» og «Fremover» **fungerer nå i flere apper**, inkludert:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed og andre kodeeditorer
- Mange innebygde Apple-apper som Forhåndsvisning, Notater, Systeminnstillinger, App Store og Musikk
- Adobe Acrobat
- Zotero
- Og flere!

Implementeringen er inspirert av den flotte «Universal Back and Forward»-funksjonen i [LinearMouse](https://github.com/linearmouse/linearmouse). Den skal støtte alle apper som LinearMouse gjør. \
I tillegg støtter den noen apper som normalt krever tastatursnarveier for å gå tilbake og fremover, som Systeminnstillinger, App Store, Apple Notater og Adobe Acrobat. Mac Mouse Fix vil nå oppdage disse appene og simulere de riktige tastatursnarveiene.

Alle apper som noen gang har blitt [forespurt i en GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) skal nå være støttet! (Takk for tilbakemeldingene!) \
Hvis du finner noen apper som ikke fungerer ennå, gi meg beskjed i en [funksjonsforespørsel](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Løser feilen «Rulling slutter å fungere periodisk»

Noen brukere opplevde et [problem](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) der **jevn rulling slutter å fungere** tilfeldig.

Selv om jeg aldri har klart å reprodusere problemet, har jeg implementert en potensiell løsning:

Appen vil nå prøve flere ganger når oppsett av skjermsynkronisering mislykkes. \
Hvis det fortsatt ikke fungerer etter nye forsøk, vil appen:

- Starte «Mac Mouse Fix Helper»-bakgrunnsprosessen på nytt, noe som kan løse problemet
- Produsere en krasjrapport, som kan hjelpe med å diagnostisere feilen

Jeg håper problemet er løst nå! Hvis ikke, gi meg beskjed i en [feilrapport](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) eller via [e-post](http://redirect.macmousefix.com/?target=mailto-noah).



### Forbedret oppførsel for frittspinnende rullehjul

Mac Mouse Fix vil **ikke lenger øke rullehastigheten** for deg når du lar rullehjulet spinne fritt på MX Master-musen. (Eller andre mus med frittspinnende rullehjul.)

Selv om denne «rulleakselerasjons»-funksjonen er nyttig på vanlige rullehjul, kan den gjøre ting vanskeligere å kontrollere på et frittspinnende rullehjul.

**Merk:** Mac Mouse Fix er for øyeblikket ikke fullt kompatibel med de fleste Logitech-mus, inkludert MX Master. Jeg planlegger å legge til full støtte, men det vil sannsynligvis ta en stund. I mellomtiden er den beste tredjepartsdriveren med Logitech-støtte jeg kjenner til [SteerMouse](https://plentycom.jp/en/steermouse/).





### Feilrettinger

- Rettet et problem der Mac Mouse Fix noen ganger reaktiverte tastatursnarveier som tidligere var deaktivert i Systeminnstillinger  
- Rettet en krasj ved klikk på «Aktiver lisens» 
- Rettet en krasj ved klikk på «Avbryt» rett etter klikk på «Aktiver lisens» (Takk for rapporten, Ali!)
- Rettet krasjer ved forsøk på å bruke Mac Mouse Fix mens ingen skjerm er koblet til Mac-en din 
- Rettet en minnelekkasje og noen andre underliggende problemer ved bytte mellom faner i appen 

### Visuelle forbedringer

- Rettet et problem der Om-fanen noen ganger var for høy, som ble introdusert i [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Tekst på «Gratis dager er over»-varslingen kuttes ikke lenger av på kinesisk
- Rettet en visuell feil på «+»-feltets skygge etter opptak av en inndata
- Rettet en sjelden feil der plassholderteksten på «Skriv inn lisensnøkkelen din»-skjermen kunne vises usentrert
- Rettet et problem der noen symboler vist i appen hadde feil farge etter bytte mellom mørk/lys modus

### Andre forbedringer

- Gjorde noen animasjoner, som fanebytte-animasjonen, litt mer effektive  
- Deaktiverte Touch Bar-tekstfullføring på «Skriv inn lisensnøkkelen din»-skjermen 
- Diverse mindre underliggende forbedringer

*Redigert med utmerket hjelp fra Claude.*

---

Sjekk også ut forrige utgivelse [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).