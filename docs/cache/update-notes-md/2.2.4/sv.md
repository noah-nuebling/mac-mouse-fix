Mac Mouse Fix **2.2.4** är nu notariserad! Den innehåller även några mindre buggfixar och andra förbättringar.

### **Notarisering**

Mac Mouse Fix 2.2.4 är nu 'notariserad' av Apple. Det betyder inga fler meddelanden om att Mac Mouse Fix potentiellt är 'Skadlig programvara' när appen öppnas för första gången.

#### Bakgrund

Att notarisera din app kostar $100 per år. Jag var alltid emot detta, eftersom det kändes fientligt mot gratis och öppen källkod som Mac Mouse Fix, och det kändes också som ett farligt steg mot att Apple kontrollerar och låser ner Mac precis som de gör med iPhone eller iPad. Men bristen på notarisering ledde till olika problem, inklusive [svårigheter att öppna appen](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) och till och med [flera situationer](https://github.com/noah-nuebling/mac-mouse-fix/issues/95) där ingen kunde använda appen förrän jag släppte en ny version.

För Mac Mouse Fix 3 tyckte jag att det äntligen var lämpligt att betala $100 per år för att notarisera appen, eftersom Mac Mouse Fix 3 är monetariserad. ([Läs mer](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Nu får Mac Mouse Fix 2 också notarisering, vilket bör leda till en enklare och mer stabil användarupplevelse.

### **Buggfixar**

- Fixade ett problem där markören försvann och sedan dök upp på en annan plats när man använde en 'Klicka och dra'-åtgärd under en skärminspelning eller medan man använde [DisplayLink](https://www.synaptics.com/products/displaylink-graphics)-programvaran.
- Fixade ett problem med att aktivera Mac Mouse Fix under macOS 10.14 Mojave och möjligen även äldre macOS-versioner.
- Förbättrad minneshantering, som potentiellt fixar en krasch av 'Mac Mouse Fix Helper'-appen som kunde inträffa när en mus kopplades bort från datorn. Se Diskussion [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Andra förbättringar**

- Fönstret som appen visar för att informera dig om att en ny version av Mac Mouse Fix finns tillgänglig stöder nu JavaScript. Detta gör att uppdateringsnotiserna kan vara snyggare och lättare att läsa. Till exempel kan uppdateringsnotiserna nu visa [Markdown Alerts](https://github.com/orgs/community/discussions/16925) och mer.
- Tog bort en länk till https://macmousefix.com/about/ från skärmen "Ge åtkomst till tillgänglighet för Mac Mouse Fix Helper". Detta eftersom About-sidan inte längre existerar och har ersatts av [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix) för tillfället.
- Denna version innehåller nu dSYM-filer som kan användas av vem som helst för att avkoda krashrapporter för Mac Mouse Fix 2.2.4.
- Vissa förbättringar och städning under huven.

---

Kolla även in den tidigare versionen [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).