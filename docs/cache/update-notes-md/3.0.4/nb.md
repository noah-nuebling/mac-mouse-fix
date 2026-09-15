Mac Mouse Fix **3.0.4** forbedrer personvern, effektivitet og pålitelighet.\
Den introduserer et nytt offline-lisensieringssystem og fikser flere viktige feil.

### Forbedret personvern og effektivitet

3.0.4 introduserer et nytt offline-lisensvalideringssystem som minimerer internettforbindelser så mye som mulig.\
Dette forbedrer personvernet og sparer datamaskinens systemressurser.\
Når appen er lisensiert, fungerer den nå 100 % offline!

<details>
<summary><b>Klikk her for flere detaljer</b></summary>
Tidligere versjoner validerte lisenser online ved hver oppstart, noe som potensielt tillot at tilkoblingslogger ble lagret av tredjepartsservere (GitHub og Gumroad). Det nye systemet eliminerer unødvendige tilkoblinger – etter den første lisensaktiveringen kobler det seg bare til internett hvis lokale lisensdata er ødelagt.
<br><br>
Selv om ingen brukeratferd noensinne ble registrert av meg personlig, tillot det forrige systemet teoretisk at tredjepartsservere kunne logge IP-adresser og tilkoblingstider. Gumroad kunne også logge lisensnøkkelen din og potensielt korrelere den med personlig informasjon de registrerte om deg da du kjøpte Mac Mouse Fix.
<br><br>
Jeg tenkte ikke på disse subtile personvernproblemene da jeg bygde det opprinnelige lisensieringssystemet, men nå er Mac Mouse Fix så privat og internettfri som mulig!
<br><br>
Se også <a href=https://gumroad.com/privacy>Gumroads personvernregler</a> og denne <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub-kommentaren</a> min.

</details>

### Feilrettinger

- Fikset en feil der macOS noen ganger kunne henge seg opp ved bruk av «Klikk og dra» for «Skrivebord og Mission Control».
- Fikset en feil der tastatursnarveier i Systeminnstillinger noen ganger ble slettet ved bruk av Mac Mouse Fix «Klikk»-handlinger som «Mission Control».
- Fikset [en feil](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) der appen noen ganger sluttet å fungere og viste en varsling om at «Gratisdagene er over» til brukere som allerede hadde kjøpt appen.
    - Hvis du opplevde denne feilen, beklager jeg virkelig ulempene. Du kan søke om [refusjon her](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Forbedret måten applikasjonen henter hovedvinduet sitt på, noe som kan ha fikset en feil der «Aktiver lisens»-skjermen noen ganger ikke vises.

### Brukervennlighetsforbedringer

- Gjort det umulig å skrive inn mellomrom og linjeskift i tekstfeltet på «Aktiver lisens»-skjermen.
    - Dette var et vanlig forvirringspunkt, fordi det er veldig lett å ved et uhell velge et skjult linjeskift når du kopierer lisensnøkkelen din fra Gumroads e-poster.
- Disse oppdateringsnotatene oversettes automatisk for ikke-engelskspråklige brukere (drevet av Claude). Jeg håper dette er nyttig! Hvis du opplever problemer med det, gi meg beskjed. Dette er et første glimt av et nytt oversettelsessystem jeg har utviklet det siste året.

### Fjernet (uoffisiell) støtte for macOS 10.14 Mojave

Mac Mouse Fix 3 støtter offisielt macOS 11 Big Sur og nyere. For brukere som var villige til å akseptere noen feil og grafiske problemer, kunne Mac Mouse Fix 3.0.3 og tidligere fortsatt brukes på macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 fjerner denne støtten og **krever nå macOS 10.15 Catalina**.\
Jeg beklager eventuelle ulemper dette medfører. Denne endringen tillot meg å implementere det forbedrede lisensieringssystemet ved hjelp av moderne Swift-funksjoner. Mojave-brukere kan fortsette å bruke Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) eller [nyeste versjon av Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Jeg håper det er en god løsning for alle.

### Forbedringer under panseret

- Implementert et nytt «MFDataClass»-system som tillater kraftigere datamodellering samtidig som Mac Mouse Fix sin konfigurasjonsfil forblir lesbar og redigerbar for mennesker.
- Bygget støtte for å legge til betalingsplattformer utover Gumroad. Så i fremtiden kan det bli lokaliserte betalingsløsninger, og appen kan selges til forskjellige land.
- Forbedret logging som lar meg lage mer effektive «Debug Builds» for brukere som opplever feil som er vanskelige å reprodusere.
- Mange andre små forbedringer og oppryddingsarbeid.

*Redigert med utmerket hjelp fra Claude.*

---

Sjekk også ut forrige utgivelse [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).