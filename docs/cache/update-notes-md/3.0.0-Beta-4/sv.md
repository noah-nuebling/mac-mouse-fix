Kolla även in **vad som var nytt** i [3.0.0 Beta 3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-3)!

---

**3.0.0 Beta 4** kommer med ett nytt **"Återställ standardinställningar..." alternativ** samt många **kvalitetsförbättringar** och **buggfixar**!

Här är **allt** som är **nytt**:

## 1. "Återställ standardinställningar..." alternativ

Det finns nu en "**Återställ standardinställningar...**" knapp på "Knappar" fliken.
Detta gör att du känner dig ännu mer **bekväm** när du **experimenterar** med inställningar.

Det finns **2 standardinställningar** tillgängliga:

1. "Standardinställning för möss med **5+ knappar**" är superkraftig och bekväm. Den låter dig faktiskt göra **allt** du gör på en **styrplatta**. Allt med hjälp av de 2 **sidoknapparna** som ligger precis där din **tumme** vilar! Men den är förstås bara tillgänglig på möss med 5 eller fler knappar.
2. "Standardinställning för möss med **3 knappar**" låter dig fortfarande göra de **viktigaste** sakerna du gör på en styrplatta - även på en mus som bara har 3 knappar.

Jag har jobbat hårt för att göra denna funktion **smart**:

- När du startar MMF för första gången kommer den **automatiskt välja** den förinställning som **passar din mus bäst**.
- När du ska återställa standardinställningarna kommer Mac Mouse Fix **visa dig** vilken **musmodell** du använder och dess **antal knappar**, så att du enkelt kan välja vilken av de två förinställningarna du vill använda. Den kommer också **förvälja** den förinställning som **passar din mus bäst**.
- När du byter till en **ny mus** som inte passar dina nuvarande inställningar kommer en popup på Knappar-fliken **påminna dig** om hur du **laddar** de rekommenderade inställningarna för din mus!
- Allt **gränssnitt** kring detta är mycket **enkelt**, **vackert** och **animeras** snyggt.

Jag hoppas att du tycker denna funktion är **användbar** och **enkel att använda**! Men låt mig veta om du har några problem.
Är något **konstigt** eller **ointuitivt**? Dyker **popupfönstren** upp **för ofta** eller i **olämpliga situationer**? **Berätta** om din upplevelse!

## 2. Mac Mouse Fix tillfälligt gratis i vissa länder

Det finns vissa **länder** där Mac Mouse Fix's **betalningsleverantör** Gumroad **inte fungerar** för närvarande.
Mac Mouse Fix är nu **gratis** i **dessa länder** tills jag kan erbjuda en alternativ betalningsmetod!

Om du befinner dig i ett av de kostnadsfria länderna kommer information om detta att **visas** på **Om-fliken** och när du **anger en licensnyckel**

Om det är **omöjligt att köpa** Mac Mouse Fix i ditt land, men det **inte är gratis** i ditt land ännu - låt mig veta så gör jag Mac Mouse Fix gratis i ditt land också!

## 3. Ett bra tillfälle att börja översätta!

Med Beta 4 har jag **implementerat alla UI-ändringar** som jag har planerat för Mac Mouse Fix 3. Så jag förväntar mig inga fler stora ändringar i användargränssnittet fram till Mac Mouse Fix 3 släpps.

Om du har väntat eftersom du förväntade dig att användargränssnittet fortfarande skulle ändras, då är **detta ett bra tillfälle** att börja **översätta** appen till ditt språk!

För **mer information** om att översätta appen, se **[3.0.0 Beta 1 Release Notes](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-1.1) > 9. Internationalization**

## 4. Allt annat

Förutom ändringarna som listats ovan innehåller Beta 4 många fler små **buggfixar**, **justeringar** och **kvalitetsförbättringar**:

### Användargränssnitt

#### Buggfixar

- Fixade bug där länkar från Om-fliken skulle öppnas om och om igen när man klickade var som helst i fönstret. Tack till GitHub-användaren [DingoBits](https://github.com/DingoBits) som fixade detta!
- Fixade några app-symboler som inte visades korrekt på äldre macOS-versioner
- Dolde rullningslister i åtgärdstabellen. Tack till GitHub-användaren [marianmelinte93](https://github.com/marianmelinte93) som gjorde mig uppmärksam på detta problem i [denna kommentar](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366#discussioncomment-3728994)!
- Fixade problem där feedback om funktioner som automatiskt återaktiveras när du öppnar respektive flik för den funktionen i användargränssnittet (efter att du inaktiverat den respektive funktionen från menyraden) inte visades på macOS Monterey och tidigare. Tack igen till [marianmelinte93](https://github.com/marianmelinte93) för att ha uppmärksammat problemet.
- Lade till saknad lokaliserbarhet och tyska översättningar för alternativet "Klicka för att rulla för att flytta mellan spaces"
- Fixade fler små lokaliserbarhetsproblem
- Lade till fler saknade tyska översättningar
- Notifieringar som visas när en knapp har fångats / inte längre är fångad fungerar nu korrekt när vissa knappar har fångats och andra har slutat fångas samtidigt.

#### Förbättringar

- Tog bort alternativet "Klicka och rulla för App Switcher". Det var lite buggigt och jag tror inte det var särskilt användbart.
- Lade till alternativet "Klicka och rulla för att rotera".
- Justerade layouten av "Mac Mouse Fix"-menyn i menyraden.
- Lade till "Köp Mac Mouse Fix"-knapp i "Mac Mouse Fix"-menyn i menyraden.
- Lade till en hjälptext under alternativet "Visa i menyrad". Målet är att göra det mer upptäckbart att menyradsobjektet kan användas för att snabbt slå av eller på funktioner
- Meddelandena "Tack för att du köper Mac Mouse Fix" på om-skärmen kan nu anpassas helt av översättare.
- Förbättrade tips för översättare
- Förbättrade UI-texter kring provperiodens utgång
- Förbättrade UI-texter på Om-fliken
- Lade till fetstilta markeringar i vissa UI-texter för att förbättra läsbarheten
- Lade till varning när man klickar på "Skicka ett e-postmeddelande"-länken på Om-fliken.
- Ändrade sorteringsordningen i åtgärdstabellen. Klicka och rulla-åtgärder kommer nu att visas före klicka och dra-åtgärder. Detta känns mer naturligt för mig eftersom raderna i tabellen nu är sorterade efter hur kraftfulla deras utlösare är (Klick < Rulla < Dra).
- Appen kommer nu att uppdatera den aktivt använda enheten när man interagerar med användargränssnittet. Detta är användbart eftersom delar av användargränssnittet nu baseras på enheten du använder. (Se den nya funktionen "Återställ standardinställningar...")
- En notifiering som visar vilka knappar som har fångats / inte längre är fångade visas nu när du startar appen för första gången.
- Fler förbättringar av notifieringar som visas när en knapp har fångats / inte längre är fångad
- Gjorde det omöjligt att av misstag ange extra mellanslag när man aktiverar en licensnyckel

### Mus

#### Buggfixar

- Förbättrade rullningssimulering för att korrekt skicka "fixed point deltas". Detta löser ett problem där rullningshastigheten var för långsam i vissa appar som Safari med mjuk rullning avstängd.
- Fixade problem där funktionen "Klicka och dra för Mission Control & Spaces" ibland kunde fastna när datorn var långsam
- Fixade ett problem där CPU:n alltid skulle användas av Mac Mouse Fix när musen flyttades efter att ha använt funktionen "Klicka och dra för att rulla & navigera"

#### Förbättringar

- Kraftigt förbättrad respons vid rullning för zoom i Chromium-baserade webbläsare som Chrome, Brave eller Edge

### Under huven

#### Buggfixar

- Fixade ett problem där Mac Mouse Fix inte skulle fungera korrekt efter att ha flyttats till en annan mapp medan den var aktiverad
- Fixade några problem med att aktivera Mac Mouse Fix medan en annan instans av Mac Mouse Fix fortfarande var aktiverad. (Detta är eftersom Apple lät mig ändra bundle ID från "com.nuebling.mac-mouse-fixxx" som användes i Beta 3 tillbaka till det ursprungliga "com.nuebling.mac-mouse-fix". Inte säker på varför.)

#### Förbättringar

- Denna och framtida betor kommer att ge mer detaljerad felsökningsinformation
- Städning och förbättringar under huven. Tog bort gammal pre-10.13-kod. Städade upp ramverk och beroenden. Källkoden är nu enklare att arbeta med, mer framtidssäker.