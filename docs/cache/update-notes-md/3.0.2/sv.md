Mac Mouse Fix **3.0.2** kommer med flera förbättringar, inklusive **jämnare scrollning**, förbättrade översättningar och mer!

### Scrollning

- Du kan nu stoppa scrollningsanimationer genom att scrolla ett steg i motsatt riktning. Detta låter dig **'kasta'** och **'fånga sidan'** när du använder 'Jämnhet: Hög', liknande en styrplatta.
- Mac Mouse Fix skickar nu scrollningshändelser tidigare i skärmuppdateringscykeln, vilket ger appar mer tid att bearbeta scrollningshändelserna och visa scrollningen jämnt. Detta **förbättrar bildfrekvensen**, särskilt på komplexa webbplatser som YouTube.com.
- Förbättrad respons för inställningen 'Jämnhet: Hög', vilket gör scrollningen lättare att kontrollera.
- Förbättrat en mekanism som introducerades i 3.0.1 där animationshastigheten blir snabbare när du rullar scrollhjulet snabbare med 'Jämnhet: Normal'. I 3.0.2 ska ökningen av animationshastigheten kännas mer konsekvent och förutsägbar, vilket gör den behagligare för ögonen samtidigt som den ger bra kontroll.
- Åtgärdat ett problem där scrollningshastigheten var för långsam, särskilt vid användning av 'Precision'-alternativet. Detta problem introducerades i 3.0.1. Tack till @V-Coba för att ha uppmärksammat det i [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- Förbättrat beteendet i Arc-webbläsaren när 'Klicka och Scrolla' används för att 'Zooma In eller Ut'.

### Lokalisering

- Uppdaterade 🇻🇳 vietnamesiska översättningar. Tack till @nghlt!
- Förbättrade några 🇩🇪 tyska översättningar.
- Text i Mac Mouse Fix som saknar översättning för det aktuella språket kommer nu visa ett platshållarvärde istället för att vara tom. Detta bör göra det mindre förvirrande att navigera i appen när det saknas översättningar.

### Övrigt

- Mac Mouse Fix kommer nu visa en notifikation med en länk till [denna guide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) för användare som kan uppleva en bugg i macOS 13 Ventura och senare som kan förhindra att Mac Mouse Fix aktiveras.
- Ändrade standardinställningarna för möss med 3 knappar. Standardinställningarna har inte längre en 'Klicka och Scrolla'-åtgärd för scrollhjulsknappen, eftersom det är ganska svårt att utföra. Istället har standardinställningarna nu en 'Håll'- och en 'Dubbelklick'-åtgärd.
- Lade till en verktygstips till Mac Mouse Fix-ikonen på Om-fliken. Den berättar hur du visar Mac Mouse Fix konfigurationsfil i Finder.
- Massor av städning och förbättringar under huven.

---

Kolla även in den tidigare versionen [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).