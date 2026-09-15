Mac Mouse Fix **2.2.4** er nå notarisert! Den inkluderer også noen små feilrettinger og andre forbedringer.

### **Notarisering**

Mac Mouse Fix 2.2.4 er nå 'notarisert' av Apple. Det betyr at du ikke lenger får meldinger om at Mac Mouse Fix potensielt er 'skadelig programvare' når du åpner appen for første gang.

#### Bakgrunn

Å notarisere appen din koster $100 per år. Jeg var alltid imot dette, siden det føltes fiendtlig mot gratis og åpen kildekode-programvare som Mac Mouse Fix, og det føltes også som et farlig skritt mot at Apple kontrollerer og låser ned Mac-en slik de gjør med iPhones eller iPads. Men mangel på notarisering førte til forskjellige problemer, inkludert [vanskeligheter med å åpne appen](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) og til og med [flere situasjoner](https://github.com/noah-nuebling/mac-mouse-fix/issues/95) der ingen kunne bruke appen før jeg slapp en ny versjon.

For Mac Mouse Fix 3 tenkte jeg at det endelig var passende å betale $100 per år for å notarisere appen, siden Mac Mouse Fix 3 er monetisert. ([Les mer](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Nå får Mac Mouse Fix 2 også notarisering, noe som burde føre til en enklere og mer stabil brukeropplevelse.

 

### **Feilrettinger**

- Fikset et problem der markøren ville forsvinne og deretter dukke opp på et annet sted når du brukte en 'Klikk og dra'-handling under et skjermopptak eller mens du brukte [DisplayLink](https://www.synaptics.com/products/displaylink-graphics)-programvaren.  
- Fikset et problem med å aktivere Mac Mouse Fix under macOS 10.14 Mojave og muligens eldre macOS-versjoner også.  
- Forbedret minnehåndtering, som potensielt fikser en krasj av 'Mac Mouse Fix Helper'-appen som oppstod når du koblet fra en mus fra datamaskinen. Se diskusjon [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).  

### **Andre forbedringer**

- Vinduet som appen viser for å informere deg om at en ny versjon av Mac Mouse Fix er tilgjengelig, støtter nå JavaScript. Dette gjør at oppdateringsnotatene kan være penere og lettere å lese. For eksempel kan oppdateringsnotatene nå vise [Markdown-varsler](https://github.com/orgs/community/discussions/16925) og mer.
- Fjernet en lenke til https://macmousefix.com/about/-siden fra «Gi tilgangstillatelse til Mac Mouse Fix Helper»-skjermen. Dette er fordi Om-siden ikke lenger eksisterer og har blitt erstattet av [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix) for nå.
- Denne utgivelsen inkluderer nå dSYM-filer som kan brukes av hvem som helst til å dekode krasjrapporter fra Mac Mouse Fix 2.2.4.
- Noe opprydding og forbedringer under panseret.

---

Sjekk også ut forrige utgivelse [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).