Kolla även in de **snygga förbättringarna** som introducerades i [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6)!


---

**3.0.0 Beta 7** innehåller flera små förbättringar och buggfixar.

Här är allt som är nytt:

**Förbättringar**

- Lagt till **koreanska översättningar**. Stort tack till @jeongtae! (Hitta honom på [GitHub](https://github.com/jeongtae))
- Gjort **scrollningen** med alternativet 'Smoothness: High' **ännu jämnare**, genom att bara ändra hastigheten gradvis, istället för att ha plötsliga hopp i scrollhastigheten när du flyttar scrollhjulet. Detta borde göra scrollningen lite jämnare och lättare att följa med ögonen utan att göra saker mindre responsiva. Scrollning med 'Smoothness: High' använder nu omkring 30% mer CPU, på min dator gick det från 1.2% CPU-användning vid kontinuerlig scrollning till 1.6%. Så scrollningen är fortfarande högst effektiv och jag hoppas att detta inte kommer göra någon skillnad för någon. Stort tack till [MOS](https://mos.caldis.me/), som inspirerade denna funktion och vars 'Scroll Monitor' jag använde för att hjälpa implementera funktionen.
- Mac Mouse Fix **hanterar nu knapptryckningar från alla källor**. Tidigare hanterade Mac Mouse Fix bara indata från möss som den kände igen. Jag tror att detta kan hjälpa kompatibiliteten med vissa möss i särskilda fall, som när man använder en Hackintosh, men det kommer också leda till att Mac Mouse Fix fångar upp artificiellt genererade knapptryckningar från andra appar, vilket kan leda till problem i andra särskilda fall. Låt mig veta om detta leder till några problem för dig, så kommer jag att åtgärda det i framtida uppdateringar.
- Förfinat känslan och finishen av 'Klicka och Scrolla' för 'Skrivbord & Launchpad' och 'Klicka och Scrolla' för att 'Flytta mellan Spaces' gesterna.
- Tar nu hänsyn till informationstätheten i ett språk när **visningstiden för notiser** beräknas. Tidigare visades notiser bara under en mycket kort tid för språk med hög informationstäthet som kinesiska eller koreanska.
- Aktiverat **olika gester** för att flytta mellan **Spaces**, öppna **Mission Control**, eller öppna **App Exposé**. I Beta 6 gjorde jag så att dessa åtgärder bara var tillgängliga genom 'Klicka och Dra'-gesten - som ett experiment för att se hur många som faktiskt brydde sig om att kunna komma åt dessa åtgärder på andra sätt. Det verkar som att vissa gör det, så nu har jag gjort det möjligt igen att komma åt dessa åtgärder genom en enkel 'Klick' på en knapp eller genom 'Klicka och Scrolla'.
- Gjort det möjligt att **Rotera** genom en **Klicka och Scrolla**-gest.
- **Förbättrat** hur **Trackpad Simulation**-alternativet fungerar i vissa scenarier. Till exempel när man scrollar horisontellt för att radera ett meddelande i Mail, är riktningen som meddelandet rör sig nu inverterad, vilket jag hoppas känns lite mer naturligt och konsekvent för de flesta.
- Lagt till en funktion för att **mappa om** till **Primärklick** eller **Sekundärklick**. Jag implementerade detta eftersom högerknappen på min favoritmus gick sönder. Dessa alternativ är dolda som standard. Du kan se dem genom att hålla ned Option-tangenten medan du väljer en åtgärd.
  - Detta saknar för närvarande översättningar till kinesiska och koreanska, så om du vill bidra med översättningar för dessa funktioner skulle det uppskattas mycket!

**Buggfixar**

- Fixat en bugg där **riktningen för 'Klicka och Dra'** för 'Mission Control & Spaces' var **inverterad** för personer som aldrig växlat 'Naturlig scrollning'-alternativet i Systeminställningar. Nu bör riktningen för 'Klicka och Dra'-gester i Mac Mouse Fix alltid matcha riktningen för gester på din Trackpad eller Magic Mouse. Om du vill ha ett separat alternativ för att invertera 'Klicka och Dra'-riktningen, istället för att den följer Systeminställningarna, låt mig veta.
- Fixat en bugg där **gratisdagarna** skulle **räknas upp för snabbt** för vissa användare. Om du påverkades av detta, låt mig veta så ska jag se vad jag kan göra.
- Fixat ett problem under macOS Sonoma där flikfältet inte visades korrekt.
- Fixat hackighet när man använder 'macOS' scrollhastighet medan man använder 'Klicka och Scrolla' för att öppna Launchpad.
- Fixat krasch där 'Mac Mouse Fix Helper'-appen (som körs i bakgrunden när Mac Mouse Fix är aktiverad) ibland skulle krascha vid inspelning av kortkommandon.
- Fixat en bugg där Mac Mouse Fix skulle krascha när den försökte fånga upp artificiella händelser genererade av [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma)
- Fixat ett problem där namnet för vissa möss som visas i 'Återställ standardinställningar...'-dialogen skulle innehålla tillverkaren två gånger.
- Gjort det mindre sannolikt att 'Klicka och Dra' för 'Mission Control & Spaces' fastnar när datorn är långsam.
- Korrigerat användningen av 'Force Touch' i UI-strängar där det borde vara 'Force click'.
- Fixat en bugg som skulle uppstå för vissa konfigurationer, där öppning av Launchpad eller visning av Skrivbordet genom 'Klicka och Scrolla' inte skulle fungera om du släppte knappen medan övergångsanimationen fortfarande pågick.

**Mer**

- Flera förbättringar under huven, stabilitetsförbättringar, städning under huven och mer.

## Hur du kan hjälpa till

Du kan hjälpa till genom att dela dina **idéer**, **problem** och **feedback**!

Bästa stället att dela dina **idéer** och **problem** är [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Bästa stället att ge **snabb** ostrukturerad feedback är [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Du kan också komma åt dessa platser inifrån appen på fliken '**ⓘ Om**'.

**Tack** för att du hjälper till att göra Mac Mouse Fix bättre! 😎:)