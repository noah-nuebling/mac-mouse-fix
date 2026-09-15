Mac Mouse Fix **3.0.8** løser UI-problemer og mer.

### **UI-problemer**

- Deaktiverte det nye designet på macOS 26 Tahoe. Nå vil appen se ut og fungere som den gjorde på macOS 15 Sequoia. 
    - Jeg gjorde dette fordi noen av Apples redesignede UI-elementer fortsatt har problemer. For eksempel var '-'-knappene på 'Knapper'-fanen ikke alltid klikkbare.
    - Brukergrensesnittet kan se litt utdatert ut på macOS 26 Tahoe nå. Men det skal være fullt funksjonelt og polert akkurat som før.
- Fikset en feil der 'Gratisdagene er over'-varslingen ble sittende fast i øvre høyre hjørne av skjermen.
    - Takk til [Sashpuri](https://github.com/Sashpuri) og andre for å ha rapportert det!

### **UI-polering**

- Deaktiverte den grønne trafikklysknappen i hovedvinduet til Mac Mouse Fix.
    - Knappen gjorde ingenting, siden vinduet ikke kan endres manuelt.
- Fikset et problem der noen av de horisontale linjene i tabellen på 'Knapper'-fanen var for mørke under macOS 26 Tahoe.
- Fikset en feil der meldingen "Primær museknapp kan ikke brukes" på 'Knapper'-fanen noen ganger ble kuttet av under macOS 26 Tahoe.
- Fikset en skrivefeil i det tyske grensesnittet. Med tillatelse fra GitHub-bruker [i-am-the-slime](https://github.com/i-am-the-slime). Takk!
- Løste et problem der MMF-vinduet noen ganger blinket kort i feil størrelse når vinduet ble åpnet på macOS 26 Tahoe.

### **Andre endringer**

- Forbedret oppførsel når man prøver å aktivere Mac Mouse Fix mens flere instanser av Mac Mouse Fix kjører på datamaskinen. 
    - Mac Mouse Fix vil nå prøve å deaktivere den andre instansen av Mac Mouse Fix mer grundig. 
    - Dette kan forbedre spesialtilfeller der Mac Mouse Fix ikke kunne aktiveres.
- Under-panseret-endringer og opprydding.

---

Sjekk også ut hva som er nytt i forrige versjon [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).