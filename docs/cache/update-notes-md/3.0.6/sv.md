Mac Mouse Fix **3.0.6** gör funktionen 'Bakåt' och 'Framåt' kompatibel med fler appar.
Den åtgärdar även flera buggar och problem.

### Förbättrad 'Bakåt' och 'Framåt'-funktion

Musknappsmappningarna för 'Bakåt' och 'Framåt' **fungerar nu i fler appar**, inklusive:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed och andra kodredigerare
- Många inbyggda Apple-appar som Förhandsvisning, Anteckningar, Systeminställningar, App Store och Musik
- Adobe Acrobat
- Zotero
- Och mer!

Implementeringen är inspirerad av den utmärkta funktionen 'Universal Back and Forward' i [LinearMouse](https://github.com/linearmouse/linearmouse). Den bör stödja alla appar som LinearMouse gör. \
Dessutom stöder den vissa appar som normalt kräver tangentbordsgenvägar för att gå bakåt och framåt, som Systeminställningar, App Store, Apple Anteckningar och Adobe Acrobat. Mac Mouse Fix kommer nu att upptäcka dessa appar och simulera lämpliga tangentbordsgenvägar.

Varje app som någonsin har [begärts i en GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) bör stödjas nu! (Tack för feedbacken!) \
Om du hittar några appar som inte fungerar än, låt mig veta i en [funktionsförfrågan](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Åtgärdar buggen 'Rullning slutar fungera periodvis'

Vissa användare upplevde ett [problem](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) där **mjuk rullning slutar fungera** slumpmässigt.

Även om jag aldrig har kunnat återskapa problemet har jag implementerat en potentiell lösning:

Appen kommer nu att försöka flera gånger när inställningen av skärmsynkroniseringen misslyckas. \
Om det fortfarande inte fungerar efter flera försök kommer appen att:

- Starta om bakgrundsprocessen 'Mac Mouse Fix Helper', vilket kan lösa problemet
- Skapa en kraschrapport, som kan hjälpa till att diagnostisera buggen

Jag hoppas att problemet är löst nu! Om inte, låt mig veta i en [buggrapport](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) eller via [e-post](http://redirect.macmousefix.com/?target=mailto-noah).



### Förbättrat beteende för frisnurrande rullhjul

Mac Mouse Fix kommer **inte längre att snabba upp rullningen** åt dig när du låter rullhjulet snurra fritt på MX Master-musen. (Eller någon annan mus med ett frisnurrande rullhjul.)

Även om denna 'rullningsacceleration' är användbar på vanliga rullhjul kan den göra saker svårare att kontrollera på ett frisnurrande rullhjul.

**Obs:** Mac Mouse Fix är för närvarande inte helt kompatibel med de flesta Logitech-möss, inklusive MX Master. Jag planerar att lägga till fullt stöd, men det kommer förmodligen att ta ett tag. Under tiden är den bästa tredjepartsdrivrutinen med Logitech-stöd som jag känner till [SteerMouse](https://plentycom.jp/en/steermouse/).





### Buggfixar

- Fixade ett problem där Mac Mouse Fix ibland återaktiverade tangentbordsgenvägar som tidigare inaktiverats i Systeminställningar  
- Fixade en krasch när man klickade på 'Aktivera licens' 
- Fixade en krasch när man klickade på 'Avbryt' direkt efter att ha klickat på 'Aktivera licens' (Tack för rapporten, Ali!)
- Fixade krascher när man försökte använda Mac Mouse Fix medan ingen skärm var ansluten till din Mac 
- Fixade en minnesläcka och några andra under-huven-problem när man växlade mellan flikar i appen 

### Visuella förbättringar

- Fixade ett problem där Om-fliken ibland var för hög, vilket introducerades i [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Text på notifikationen 'Gratisdagarna är över' är inte längre avklippt på kinesiska
- Fixade en visuell bugg på '+'-fältets skugga efter inspelning av en inmatning
- Fixade en sällsynt bugg där platshållartexten på skärmen 'Ange din licensnyckel' kunde visas off-center
- Fixade ett problem där vissa symboler som visades i appen hade fel färg efter byte mellan mörkt/ljust läge

### Övriga förbättringar

- Gjorde vissa animationer, som flikbytesanimationen, något mer effektiva  
- Inaktiverade Touch Bar-textkomplettering på skärmen 'Ange din licensnyckel' 
- Diverse mindre under-huven-förbättringar

*Redigerad med utmärkt hjälp av Claude.*

---

Kolla även in den tidigare versionen [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).