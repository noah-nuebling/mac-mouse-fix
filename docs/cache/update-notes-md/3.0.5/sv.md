Mac Mouse Fix **3.0.5** fixar flera buggar, förbättrar prestandan och ger appen lite extra polish. \
Den är också kompatibel med macOS 26 Tahoe.

### Förbättrad simulering av trackpad-scrollning

- Scrollsystemet kan nu simulera en tvåfingertryckning på trackpaden för att få applikationer att sluta scrolla.
    - Detta fixar ett problem när man kör iPhone- eller iPad-appar, där scrollningen ofta fortsatte efter att användaren valt att stoppa.
- Fixade inkonsekvent simulering av att lyfta fingrarna från trackpaden.
    - Detta kan ha orsakat suboptimalt beteende i vissa situationer.



### macOS 26 Tahoe-kompatibilitet

När man kör macOS 26 Tahoe Beta är appen nu användbar, och det mesta av användargränssnittet fungerar korrekt.



### Prestandaförbättring

Förbättrad prestanda för Klicka och dra till "Scrolla & navigera"-gesten. \
I mina tester har CPU-användningen minskat med ~50%!

**Bakgrund**

Under "Scrolla & navigera"-gesten ritar Mac Mouse Fix en falsk muspekare i ett transparent fönster, samtidigt som den riktiga muspekaren låses på plats. Detta säkerställer att du kan fortsätta scrolla det UI-element som du började scrolla på, oavsett hur långt du flyttar musen.

Den förbättrade prestandan uppnåddes genom att stänga av standardhanteringen av macOS-händelser på detta transparenta fönster, som ändå inte användes.





### Buggfixar

- Ignorerar nu scrollhändelser från Wacom-ritplattor.
    - Tidigare orsakade Mac Mouse Fix hackig scrollning på Wacom-plattor, som rapporterades av @frenchie1980 i GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Tack!)
    
- Fixade en bugg där Swift Concurrency-koden, som introducerades som en del av det nya licenssystemet i Mac Mouse Fix 3.0.4, inte kördes på rätt tråd.
    - Detta orsakade krascher på macOS Tahoe, och det orsakade troligen även andra sporadiska buggar kring licensiering.
- Förbättrade robustheten i koden som avkodar offlinelicenser.
    - Detta kringgår ett problem i Apples API:er som orsakade att offlinelicensvalidering alltid misslyckades på min Intel Mac Mini. Jag antar att detta hände på alla Intel-Macar, och att det var anledningen till att "Gratisdagarna är över"-buggen (som redan åtgärdades i 3.0.4) fortfarande förekom för vissa personer, som rapporterades av @toni20k5267 i GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Tack!)
        - Om du upplevde "Gratisdagarna är över"-buggen, ber jag om ursäkt för det! Du kan få en återbetalning [här](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### UX-förbättringar

- Inaktiverade dialogrutor som gav steg-för-steg-lösningar för macOS-buggar som hindrade användare från att aktivera Mac Mouse Fix.
    - Dessa problem förekom endast på macOS 13 Ventura och 14 Sonoma. Nu visas dessa dialogrutor endast på de macOS-versioner där de är relevanta. 
    - Dialogrutorna är också lite svårare att utlösa – tidigare dök de ibland upp i situationer där de inte var särskilt hjälpsamma.
    
- Lade till en "Aktivera licens"-länk direkt på "Gratisdagarna är över"-notifikationen. 
    - Detta gör aktiveringen av en Mac Mouse Fix-licens ännu mer problemfri!

### Visuella förbättringar

- Förbättrade utseendet på "Programuppdatering"-fönstret något. Nu passar det bättre med macOS 26 Tahoe. 
    - Detta gjordes genom att anpassa standardutseendet för "Sparkle 1.27.3"-ramverket som Mac Mouse Fix använder för att hantera uppdateringar.
- Fixade problem där texten längst ner på Om-fliken ibland klipptes av på kinesiska, genom att göra fönstret något bredare.
- Fixade att texten längst ner på Om-fliken var något off-center.
- Fixade en bugg som orsakade att utrymmet under "Tangentbordsgenväg..."-alternativet på Knappar-fliken var för litet. 

### Under-huven-ändringar

- Tog bort beroendet av "SnapKit"-ramverket.
    - Detta minskar appens storlek något från 19,8 till 19,5 MB.
- Diverse andra små förbättringar i kodbasen.

*Redigerad med utmärkt hjälp från Claude.*

---

Kolla även in den tidigare versionen [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).