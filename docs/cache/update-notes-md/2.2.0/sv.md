Kolla även in de **coola grejerna** som introducerades i [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

Mac Mouse Fix **2.2.0** innehåller olika användarvänlighetsförbättringar och buggfixar!

### Ommappning till Apple-exklusiva funktionstangenter är nu bättre

Förra uppdateringen, 2.1.0, introducerade en cool ny funktion som låter dig mappa om dina musknappar till vilken tangent som helst på ditt tangentbord - även funktionstangenter som bara finns på Apple-tangentbord. 2.2.0 innehåller ytterligare förbättringar och förfiningar av den funktionen:

- Du kan nu hålla in Option (⌥) för att mappa om till tangenter som bara finns på Apple-tangentbord - även om du inte har ett Apple-tangentbord tillgängligt.
- Funktionstangenternas symboler har fått ett förbättrat utseende som passar bättre ihop med annan text.
- Möjligheten att mappa om till Caps Lock har inaktiverats. Det fungerade inte som förväntat.

### Lägg till / ta bort Åtgärder enklare

Vissa användare hade svårt att förstå att man kan lägga till och ta bort Åtgärder från Åtgärdstabellen. För att göra det lättare att förstå innehåller 2.2.0 följande ändringar och nya funktioner:

- Du kan nu ta bort Åtgärder genom att högerklicka på dem.
  - Detta bör göra det lättare att upptäcka alternativet att ta bort Åtgärder.
  - Högerklicksmenyn visar en symbol för '-'-knappen. Detta bör hjälpa till att dra uppmärksamhet till '-'-_knappen_, som i sin tur bör dra uppmärksamhet till '+'-knappen. Detta gör förhoppningsvis alternativet att **lägga till** Åtgärder mer upptäckbart.
- Du kan nu lägga till Åtgärder i Åtgärdstabellen genom att högerklicka på en tom rad.
- '-'-knappen är nu bara aktiv när en Åtgärd är markerad. Detta bör göra det tydligare att '-'-knappen tar bort den markerade Åtgärden.
- Standardhöjden på fönstret har ökats så att det finns en synlig tom rad som kan högerklickas för att lägga till en Åtgärd.
- '+' och '-'-knapparna har nu verktygstips.

### Förbättringar för Klicka och Dra

Tröskelvärdet för att aktivera Klicka och Dra har ökats från 5 pixlar till 7 pixlar. Detta gör det svårare att av misstag aktivera Klicka och Dra, samtidigt som användare fortfarande kan byta Spaces etc. med små, bekväma rörelser.

### Andra UI-ändringar

- Utseendet på Åtgärdstabellen har förbättrats.
- Olika andra UI-förbättringar.

### Buggfixar

- Åtgärdade ett problem där användargränssnittet inte gråades ut när MMF startades medan det var inaktiverat.
- Tog bort det dolda alternativet "Knapp 3 Klicka och Dra".
  - När man valde det kraschade appen. Jag byggde detta alternativ för att göra Mac Mouse Fix mer kompatibelt med Blender. Men i sin nuvarande form är det inte särskilt användbart för Blender-användare eftersom du inte kan kombinera det med tangentbordsmodifierare. Jag planerar att förbättra Blender-kompatibiliteten i en framtida release.