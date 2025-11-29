Mac Mouse Fix **3.0.3** är redo för macOS 15 Sequoia. Den åtgärdar även några stabilitetsproblem och innehåller flera små förbättringar.

### Stöd för macOS 15 Sequoia

Appen fungerar nu korrekt under macOS 15 Sequoia!

- De flesta UI-animationer var trasiga under macOS 15 Sequoia. Nu fungerar allt som det ska igen!
- Källkoden går nu att bygga under macOS 15 Sequoia. Tidigare fanns det problem med Swift-kompilatorn som hindrade appen från att byggas.

### Åtgärdar scrollkrascher

Sedan Mac Mouse Fix 3.0.2 har det kommit [flera rapporter](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) om att Mac Mouse Fix periodiskt inaktiverar och återaktiverar sig själv vid scrollning. Detta orsakades av krascher i bakgrundsappen 'Mac Mouse Fix Helper'. Denna uppdatering försöker åtgärda dessa krascher med följande ändringar:

- Scrollmekanismen kommer att försöka återhämta sig och fortsätta köra istället för att krascha när den stöter på det specialfall som verkar ha lett till dessa krascher.
- Jag har ändrat hur oväntade tillstånd hanteras i appen mer generellt: Istället för att alltid krascha omedelbart kommer appen nu att försöka återhämta sig från oväntade tillstånd i många fall.
    
    - Denna ändring bidrar till åtgärderna för scrollkrascherna som beskrivs ovan. Den kan även förhindra andra krascher.
  
Sidoanteckning: Jag kunde aldrig återskapa dessa krascher på min maskin, och jag är fortfarande inte säker på vad som orsakade dem, men baserat på de rapporter jag fått borde denna uppdatering förhindra eventuella krascher. Om du fortfarande upplever krascher vid scrollning eller om du *upplevde* krascher under 3.0.2, skulle det vara värdefullt om du delade din upplevelse och diagnostikdata i GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Detta skulle hjälpa mig att förstå problemet och förbättra Mac Mouse Fix. Tack!

### Åtgärdar scrollhackningar

I 3.0.2 gjorde jag ändringar i hur Mac Mouse Fix skickar scrollhändelser till systemet i ett försök att minska scrollhackningar som troligen orsakas av problem med Apples VSync-API:er.

Men efter mer omfattande testning och feedback verkar det som att den nya mekanismen i 3.0.2 gör scrollningen smidigare i vissa scenarion men mer hackig i andra. Särskilt i Firefox verkade det vara märkbart sämre. \
Sammantaget var det inte tydligt att den nya mekanismen faktiskt förbättrade scrollhackningar över hela linjen. Den kan också ha bidragit till scrollkrascherna som beskrivs ovan.

Därför inaktiverade jag den nya mekanismen och återställde VSync-mekanismen för scrollhändelser till hur den var i Mac Mouse Fix 3.0.0 och 3.0.1.

Se GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) för mer information.

### Återbetalning

Jag ber om ursäkt för besväret relaterat till scrolländringarna i 3.0.1 och 3.0.2. Jag underskattade kraftigt de problem som skulle komma med det, och jag var långsam med att åtgärda dessa problem. Jag ska göra mitt bästa för att lära mig av denna erfarenhet och vara mer försiktig med sådana ändringar i framtiden. Jag vill också erbjuda alla som drabbats en återbetalning. Klicka bara [här](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) om du är intresserad.

### Smartare uppdateringsmekanism

Dessa ändringar har tagits över från Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) och [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Kolla in deras versionsanteckningar för att lära dig mer om detaljerna. Här är en sammanfattning:

- Det finns en ny, smartare mekanism som bestämmer vilken uppdatering som ska visas för användaren.
- Bytte från att använda Sparkle 1.26.0 uppdateringsramverket till senaste Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- Fönstret som appen visar för att informera dig om att en ny version av Mac Mouse Fix finns tillgänglig stöder nu JavaScript, vilket möjliggör snyggare formatering av uppdateringsanteckningarna.

### Övriga förbättringar & buggfixar

- Åtgärdade ett problem där apppriset och relaterad information visades felaktigt på fliken 'Om' i vissa fall.
- Åtgärdade ett problem där mekanismen för att synkronisera den mjuka scrollningen med skärmens uppdateringsfrekvens inte fungerade korrekt vid användning av flera skärmar.
- Massor av mindre städning och förbättringar under huven.

---

Kolla även in den tidigare versionen [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).