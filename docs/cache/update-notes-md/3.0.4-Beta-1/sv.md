Mac Mouse Fix **3.0.4 Beta 1** förbättrar integritet, effektivitet och tillförlitlighet.\
Den introducerar ett nytt offline-licenssystem och åtgärdar flera viktiga buggar.

### Förbättrad integritet & effektivitet

- Introducerar ett nytt offline-licensvalideringssystem som minimerar internetanslutningar.
- Appen ansluter nu till internet endast när det är absolut nödvändigt, vilket skyddar din integritet och minskar resursanvändningen.
- Appen fungerar helt offline vid normal användning när den är licensierad.

<details>
<summary><b>Detaljerad integritetsinformation</b></summary>
Tidigare versioner validerade licenser online vid varje start, vilket potentiellt tillät att anslutningsloggar lagrades av tredjepartsservrar (GitHub och Gumroad). Det nya systemet eliminerar onödiga anslutningar – efter den första licensaktiveringen ansluter det endast till internet om lokala licensdata är korrupta.
<br><br>
Även om jag personligen aldrig registrerade något användarbeteende, tillät det tidigare systemet teoretiskt tredjepartsservrar att logga IP-adresser och anslutningstider. Gumroad kunde också logga din licensnyckel och potentiellt koppla den till personlig information som de registrerade om dig när du köpte Mac Mouse Fix.
<br><br>
Jag övervägde inte dessa subtila integritetsfrågor när jag byggde det ursprungliga licenssystemet, men nu är Mac Mouse Fix så privat och internetfri som möjligt!
<br><br>
Se även <a href=https://gumroad.com/privacy>Gumroads integritetspolicy</a> och min <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub-kommentar</a>.

</details>

### Buggfixar

- Åtgärdade en bugg där macOS ibland fastnade när man använde 'Klicka och dra' för 'Spaces & Mission Control'.
- Åtgärdade en bugg där tangentbordsgenvägar i Systeminställningar ibland raderades när man använde en 'Klick'-åtgärd definierad i Mac Mouse Fix som 'Mission Control'.
- Åtgärdade [en bugg](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) där appen ibland slutade fungera och visade en notifikation om att 'Gratisdagarna är över' för användare som redan hade köpt appen.
    - Om du upplevde denna bugg ber jag uppriktigt om ursäkt för besväret. Du kan ansöka om [återbetalning här](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).

### Tekniska förbättringar

- Implementerade ett nytt 'MFDataClass'-system som möjliggör renare datamodellering och lättlästa konfigurationsfiler.
- Byggde stöd för att lägga till andra betalningsplattformar än Gumroad. Så i framtiden kan det finnas lokaliserade kassor, och appen kan säljas till olika länder!

### Avslutat (inofficiellt) stöd för macOS 10.14 Mojave

Mac Mouse Fix 3 stöder officiellt macOS 11 Big Sur och senare. För användare som var villiga att acceptera vissa buggar och grafiska problem kunde Mac Mouse Fix 3.0.3 och tidigare fortfarande användas på macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 avslutar det stödet och **kräver nu macOS 10.15 Catalina**.\
Jag ber om ursäkt för eventuella besvär som detta orsakar. Denna förändring gjorde det möjligt för mig att implementera det förbättrade licenssystemet med moderna Swift-funktioner. Mojave-användare kan fortsätta använda Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) eller [senaste versionen av Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Jag hoppas att det är en bra lösning för alla.

*Redigerad med utmärkt hjälp från Claude.*

---

Kolla även in den tidigare versionen [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).