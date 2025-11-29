Mac Mouse Fix **3.0.4** förbättrar integritet, effektivitet och tillförlitlighet.\
Den introducerar ett nytt offline-licenssystem och fixar flera viktiga buggar.

### Förbättrad integritet & effektivitet

3.0.4 introducerar ett nytt offline-licensvalideringssystem som minimerar internetanslutningar så mycket som möjligt.\
Detta förbättrar integriteten och sparar datorns systemresurser.\
När appen är licensierad fungerar den nu 100% offline!

<details>
<summary><b>Klicka här för mer information</b></summary>
Tidigare versioner validerade licenser online vid varje start, vilket potentiellt kunde tillåta att anslutningsloggar lagrades av tredjepartsservrar (GitHub och Gumroad). Det nya systemet eliminerar onödiga anslutningar – efter den initiala licensaktiveringen ansluter den bara till internet om lokal licensdata är korrupt.
<br><br>
Även om inget användarbeteende någonsin registrerades av mig personligen, tillät det tidigare systemet teoretiskt tredjepartsservrar att logga IP-adresser och anslutningstider. Gumroad kunde också logga din licensnyckel och potentiellt korrelera den med eventuell personlig information de registrerade om dig när du köpte Mac Mouse Fix.
<br><br>
Jag övervägde inte dessa subtila integritetsproblem när jag byggde det ursprungliga licenssystemet, men nu är Mac Mouse Fix så privat och internetfri som möjligt!
<br><br>
Se även <a href=https://gumroad.com/privacy>Gumroads integritetspolicy</a> och denna <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub-kommentar</a> från mig.

</details>

### Buggfixar

- Fixade en bugg där macOS ibland kunde fastna när man använde 'Klicka och dra' för 'Spaces & Mission Control'.
- Fixade en bugg där kortkommandon i Systeminställningar ibland raderades när man använde Mac Mouse Fix 'Klick'-åtgärder som 'Mission Control'.
- Fixade [en bugg](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) där appen ibland slutade fungera och visade en notifikation om att 'Gratisdagarna är över' för användare som redan hade köpt appen.
    - Om du upplevde denna bugg ber jag uppriktigt om ursäkt för besväret. Du kan ansöka om [återbetalning här](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Förbättrade sättet applikationen hämtar sitt huvudfönster, vilket kan ha fixat en bugg där 'Aktivera licens'-skärmen ibland inte visades.

### Användbarhetsförbättringar

- Gjorde det omöjligt att skriva in mellanslag och radbrytningar i textfältet på 'Aktivera licens'-skärmen.
    - Detta var en vanlig förvirringspunkt, eftersom det är väldigt lätt att av misstag markera en dold radbrytning när man kopierar sin licensnyckel från Gumroads e-postmeddelanden.
- Dessa uppdateringsanteckningar översätts automatiskt för icke-engelsktalande användare (Drivs av Claude). Jag hoppas att detta är till hjälp! Om du stöter på några problem med det, låt mig veta. Detta är en första glimt av ett nytt översättningssystem som jag har utvecklat under det senaste året.

### Borttaget (inofficiellt) stöd för macOS 10.14 Mojave

Mac Mouse Fix 3 stöder officiellt macOS 11 Big Sur och senare. Men för användare som var villiga att acceptera vissa buggar och grafiska problem kunde Mac Mouse Fix 3.0.3 och tidigare fortfarande användas på macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 tar bort det stödet och **kräver nu macOS 10.15 Catalina**.\
Jag ber om ursäkt för eventuella besvär detta orsakar. Denna förändring gjorde det möjligt för mig att implementera det förbättrade licenssystemet med moderna Swift-funktioner. Mojave-användare kan fortsätta använda Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) eller den [senaste versionen av Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Jag hoppas att det är en bra lösning för alla.

### Under-huven-förbättringar

- Implementerade ett nytt 'MFDataClass'-system som möjliggör mer kraftfull datamodellering samtidigt som Mac Mouse Fix:s konfigurationsfil förblir läsbar och redigerbar för människor.
- Byggde stöd för att lägga till andra betalningsplattformar än Gumroad. Så i framtiden kan det finnas lokaliserade kassor, och appen skulle kunna säljas till olika länder.
- Förbättrad loggning som gör det möjligt för mig att skapa mer effektiva "Debug Builds" för användare som upplever svårreproducerade buggar.
- Många andra små förbättringar och städarbete.

*Redigerad med utmärkt hjälp från Claude.*

---

Kolla även in den tidigare versionen [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).