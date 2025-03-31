Kolla även in de **snygga ändringarna** som infördes i [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

**3.0.0 Beta 6** innehåller djupa optimeringar och förbättringar, en omarbetning av scrollningsinställningarna, kinesiska översättningar och mer!

Här är allt som är nytt:

## 1. Djupa optimeringar

För denna Beta har jag lagt ner mycket arbete på att få ut maximal prestanda ur Mac Mouse Fix. Och nu kan jag glatt meddela att när du klickar på en musknapp i Beta 6 är det **2x** snabbare jämfört med föregående beta! Och scrollning är till och med **4x** snabbare!

Med Beta 6 kommer MMF också smart att stänga av delar av sig själv för att spara så mycket CPU och batteri som möjligt.

Till exempel, när du för närvarande använder en mus med 3 knappar men bara har ställt in åtgärder för knappar som inte finns på din mus, som knapp 4 och 5, kommer Mac Mouse Fix att sluta lyssna på knapptryckningar från din mus helt. Det betyder 0% CPU-användning när du klickar på en knapp på din mus! Eller när scrollningsinställningarna i MMF matchar systemet kommer Mac Mouse Fix att sluta lyssna på inmatning från ditt scrollhjul helt. Det betyder 0% CPU-användning när du scrollar! Men om du ställer in Command (⌘)-Scroll för zoomfunktionen kommer Mac Mouse Fix att börja lyssna på ditt scrollhjuls inmatning - men bara medan du håller ner Command (⌘)-tangenten. Och så vidare.
Så den är verkligen smart och kommer bara att använda CPU när det behövs!

Detta innebär att MMF nu inte bara är den mest kraftfulla, användarvänliga och polerade musdrivrutinen för Mac, den är också en av, om inte den mest optimerade och effektiva!

## 2. Minskad appstorlek

Med 16 MB är Beta 6 ca 2x mindre än Beta 5!

Detta är en bieffekt av att stödet för äldre macOS-versioner har tagits bort.

## 3. Borttaget stöd för äldre macOS-versioner

Jag försökte hårt att få MMF 3 att fungera ordentligt på macOS-versioner före macOS 11 Big Sur. Men mängden arbete för att få det att kännas polerat visade sig vara överväldigande, så jag var tvungen att ge upp det.

Framöver kommer den tidigaste officiellt stödda versionen att vara macOS 11 Big Sur.

Appen kommer fortfarande att öppnas på äldre versioner men det kommer att finnas visuella och kanske andra problem. Appen kommer inte längre att öppnas på macOS-versioner före 10.14.4. Detta är vad som gör att vi kan krympa appstorleken med 2x eftersom 10.14.4 är den tidigaste macOS-versionen som levereras med moderna Swift-bibliotek (Se "Swift ABI Stability"), vilket betyder att dessa Swift-bibliotek inte längre behöver finnas i appen.

## 4. Scrollningsförbättringar

Beta 6 innehåller många förbättringar av konfigurationen och användargränssnittet för de nya scrollningssystemen som infördes i MMF 3.

### Användargränssnitt

- Kraftigt förenklad och förkortad UI-text på Scroll-fliken. De flesta omnämnanden av ordet "Scroll" har tagits bort eftersom det underförstås av sammanhanget.
- Omarbetat inställningarna för scrollningsjämnhet för att vara mycket tydligare och tillåta några ytterligare alternativ. Nu kan du välja mellan en "Jämnhet" på "Av", "Normal" eller "Hög", som ersätter den gamla "med tröghet"-växeln. Jag tycker detta är mycket tydligare och det gjorde plats i användargränssnittet för det nya "Trackpad-simulering"-alternativet.
- Att stänga av det nya "Trackpad-simulering"-alternativet inaktiverar gummibandseffekten medan du scrollar, det förhindrar också scrollning mellan sidor i Safari och andra appar, med mera. Många har varit irriterade på detta, särskilt de med fritt snurrande scrollhjul som finns på vissa Logitech-möss som MX Master, men andra gillar det, så jag bestämde mig för att göra det till ett alternativ. Jag hoppas att presentationen av funktionen är tydlig. Om du har några förslag där, låt mig veta.
- Ändrat alternativet "Naturlig scrollriktning" till "Omvänd scrollriktning". Detta innebär att inställningen nu vänder systemets scrollriktning och inte längre är oberoende av systemets scrollriktning. Även om detta kan ses som en något sämre användarupplevelse, möjliggör detta nya sätt att göra saker vissa optimeringar och det gör det mer transparent för användaren hur man helt stänger av Mac Mouse Fix för scrollning.
- Förbättrat hur scrollningsinställningarna interagerar med modifierad scrollning i många olika kantfall. T.ex. kommer "Precision"-alternativet inte längre att gälla för "Klicka och scrolla" för "Skrivbord & Launchpad"-åtgärden eftersom det är ett hinder här istället för att vara hjälpsamt.
- Förbättrad scrollhastighet när du använder "Klicka och scrolla" för "Skrivbord & Launchpad" eller "Zooma in eller ut" och andra funktioner.
- Tagit bort icke-fungerande länk till systemets scrollhastighetsinställningar på scroll-fliken som fanns på macOS-versioner före macOS 13.0 Ventura. Jag kunde inte hitta ett sätt att få länken att fungera och det är inte särskilt viktigt.

### Scrollkänsla

- Förbättrad animationskurva för "Normal jämnhet" (tidigare tillgänglig genom att stänga av "med tröghet"). Detta gör saker mer smidiga och responsiva.
- Förbättrad känsla för alla scrollhastighetsinställningar. "Medium" hastigheten och "Snabb" hastigheten är snabbare. Det är mer separation mellan "Låg" "Medium" och "Hög" hastigheter. Accelerationen när du flyttar scrollhjulet snabbare känns mer naturlig och bekväm när du använder "Precision"-alternativet.
- Sättet som scrollningshastigheten ökar när du fortsätter att scrolla i en riktning kommer att kännas mer naturligt och gradvis. Jag använder nya matematiska kurvor för att modellera accelerationen. Hastighetsökningen kommer också att vara svårare att utlösa av misstag.
- Ökar inte längre scrollningshastigheten när du fortsätter att scrolla i en riktning medan du använder "macOS" scrollningshastighet.
- Begränsat scrollanimationstiden till ett maximum. Om scrollanimationen naturligt skulle ta längre tid kommer den att snabbas upp för att hålla sig under den maximala tiden. På så sätt kommer scrollning in i sidkanten med ett fritt snurrande hjul inte att få sidinnehållet att flytta sig utanför skärmen lika länge. Detta bör inte påverka normal scrollning med ett icke-fritt snurrande hjul.
- Förbättrat vissa interaktioner kring gummibandseffekten när du scrollar in i en sidkant i Safari och andra appar.
- Fixat ett problem där "Klicka och scrolla" och andra scrollrelaterade funktioner inte fungerade korrekt efter uppgradering från en mycket gammal inställningspanel-version av Mac Mouse Fix.
- Fixat ett problem där enpixels-scrollningar skickades med fördröjning när "macOS" scrollningshastighet användes tillsammans med mjuk scrollning.
- Fixat en bugg där scrollningen fortfarande var väldigt snabb efter att ha släppt Snabb Scroll-modifieraren. Andra förbättringar kring hur scrollhastighet överförs från tidigare scrollsvep.
- Förbättrat hur scrollhastigheten ökar med större skärmstorlekar.

## 5. Notarisering

Från och med 3.0.0 Beta 6 kommer Mac Mouse Fix att vara "Notariserad". Det betyder inga fler meddelanden om att Mac Mouse Fix potentiellt är "Skadlig programvara" när du öppnar appen för första gången.

Att notarisera din app kostar $100 per år. Jag var alltid emot detta, eftersom det kändes fientligt mot gratis och öppen källkod som Mac Mouse Fix, och det kändes också som ett farligt steg mot att Apple kontrollerar och låser ner Mac som de gör med iOS. Men bristen på notarisering ledde till ganska allvarliga problem, inklusive [flera situationer](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) där ingen kunde använda appen förrän jag släppte en ny version. Eftersom Mac Mouse Fix nu kommer att monetariseras, tyckte jag att det äntligen var lämpligt att notarisera appen för en enklare och mer stabil användarupplevelse.

## 6. Kinesiska översättningar

Mac Mouse Fix finns nu på kinesiska!
Mer specifikt finns den på:

- Kinesiska, traditionell
- Kinesiska, förenklad
- Kinesiska (Hong Kong)

Stort tack till @groverlynn för att ha tillhandahållit alla dessa översättningar samt för att ha uppdaterat dem genom betaversionerna och kommunicerat med mig. Se hans pull request här: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Allt annat

Förutom ändringarna som listats ovan innehåller Beta 6 också många mindre förbättringar.

- Tagit bort flera alternativ från "Klicka", "Klicka och håll" och "Klicka och scrolla" åtgärderna eftersom jag tyckte de var överflödiga då samma funktionalitet kan uppnås på annat sätt och eftersom detta rensar upp menyerna mycket. Kommer att ta tillbaka dessa alternativ om folk klagar. Så om du saknar dessa alternativ - klaga gärna.
- Klicka och dra-riktningen kommer nu att matcha styrplattans svepriktning även när "Naturlig scrollning" är avstängd under Systeminställningar > Styrplatta. Tidigare betedde sig Klicka och dra alltid som att svepa på styrplattan med "Naturlig scrollning" påslagen.
- Fixat ett problem där markörerna skulle försvinna och sedan dyka upp någon annanstans när "Klicka och dra"-åtgärden användes under en skärminspelning eller när DisplayLink-programvaran användes.
- Fixat centrering av "+" i "+"-fältet på Knappar-fliken
- Flera visuella förbättringar av knappar-fliken. Färgpaletten för "+"-fältet och åtgärdstabellen har omarbetats för att se korrekt ut när macOS "Tillåt bakgrundstoning i fönster"-alternativet används. Kanterna på åtgärdstabellen har nu en transparent färg som ser mer dynamisk ut och anpassar sig till omgivningen.
- Gjort så att när du lägger till många åtgärder i åtgärdstabellen och Mac Mouse Fix-fönstret växer, kommer det att växa exakt så stort som skärmen (eller som skärmen minus dockan om du inte har docka-döljning aktiverad) och sedan stanna. När du lägger till ännu fler åtgärder kommer åtgärdstabellen att börja scrolla.
- Denna Beta stöder nu en ny utcheckning där du kan köpa en licens i US-dollar som annonserat. Tidigare kunde du bara köpa en licens i Euro. De gamla Euro-licenserna kommer naturligtvis fortfarande att stödjas.
- Fixat ett problem där tröghetssrollning ibland inte startades när "Scrolla & Navigera"-funktionen användes.
- När Mac Mouse Fix-fönstret ändrar storlek under en flikväxling kommer det nu att ompositionera sig så att det inte överlappar med Dockan
- Fixat flimmer på vissa UI-element när man byter från Knappar-fliken till en annan flik
- Förbättrat utseendet på animationen som "+"-fältet spelar upp efter att ha spelat in en inmatning. Särskilt på macOS-versioner före Ventura, där skuggan av "+"-fältet skulle se felaktig ut under animationen.
- Inaktiverat meddelanden som listar flera knappar som har fångats/inte längre fångas av Mac Mouse Fix som skulle visas när appen startas för första gången eller när en förinställning laddas. Jag tyckte dessa meddelanden var distraherande och något överväldigande och inte särskilt hjälpsamma i dessa sammanhang.
- Omarbetat skärmen för att bevilja tillgänglighetsåtkomst. Den kommer nu att visa information om varför Mac Mouse Fix behöver tillgänglighetsåtkomst inline istället för att länka till webbplatsen och den är lite tydligare och har en mer visuellt tilltalande layout.
- Uppdaterat Erkännanden-länken på Om-fliken.
- Förbättrat felmeddelanden när Mac Mouse Fix inte kan aktiveras eftersom det finns en annan version på systemet. Meddelandet kommer nu att visas i ett flytande varningsfönster som alltid stannar ovanpå andra fönster tills det avfärdas istället för ett Toast-meddelande som försvinner när man klickar någonstans. Detta bör göra det enklare att följa de föreslagna lösningsstegen.
- Fixat några problem med markdown-rendering på macOS-versioner före Ventura. MMF kommer nu att använda en anpassad markdown-renderingslösning för alla macOS-versioner, inklusive Ventura. Tidigare använde vi ett system-API som introducerades i Ventura men det ledde till inkonsekvenser. Markdown används för att lägga till länkar och betoning i text över hela användargränssnittet.
- Polerat interaktionerna kring aktivering av tillgänglighetsåtkomst.
- Fixat ett problem där appfönstret ibland skulle öppnas utan att visa något innehåll tills du bytte till en av flikarna.
- Fixat ett problem med "+"-fältet där du ibland inte kunde lägga till en ny åtgärd även om det visade en hover-effekt som indikerade att du kan ange en åtgärd.
- Fixat ett dödläge och flera andra små problem som ibland kunde hända när muspekaren flyttades inuti "+"-fältet
- Fixat ett problem där en popover som visas på Knappar-fliken när din mus inte verkar passa de aktuella knappinställningarna ibland skulle ha all text i fetstil.
- Uppdaterat alla omnämnanden av den gamla MIT-licensen till den nya MMF-licensen. Nya filer som skapas för projektet kommer nu att innehålla en autogenererad rubrik som nämner MMF-licensen.
- Gjort så att byte till Knappar-fliken aktiverar MMF för scrollning. Annars kunde du inte spela in Klicka och scrolla-gester.
- Fixat några problem där knappnamn inte visades korrekt i åtgärdstabellen i vissa situationer.
- Fixat en bugg där provperiodssektionen på Om-skärmen skulle se felaktig ut när appen öppnades och sedan bytte till provperiods-fliken efter att provperioden löpt ut.
- Fixat en bugg där Aktivera licens-länken i provperiodssektionen på Om-fliken ibland inte reagerade på klick.
- Fixat en minnesläcka när "Klicka och dra" för "Spaces & Mission Control"-funktionen används.
- Aktiverat förstärkt runtime på huvudappen Mac Mouse Fix, förbättrar säkerheten
- Mycket kodstädning, projektomstrukturering
- Flera andra krascher fixade
- Flera minnesläckor fixade
- Olika små UI-textjusteringar
- Omarbetningar av flera interna system förbättrade också robusthet och beteende i kantfall

## 8. Hur du kan hjälpa till

Du kan hjälpa till genom att dela dina **idéer**, **problem** och **feedback**!

Bästa platsen att dela dina **idéer** och **problem** är [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Bästa platsen att ge **snabb** ostrukturerad feedback är [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Du kan också nå dessa platser inifrån appen på "**ⓘ Om**"-fliken.

**Tack** för att du hjälper till att göra Mac Mouse Fix så bra som möjligt! 🙌:)