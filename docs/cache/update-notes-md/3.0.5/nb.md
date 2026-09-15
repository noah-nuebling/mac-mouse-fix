Mac Mouse Fix **3.0.5** fikser flere feil, forbedrer ytelsen og legger til litt finpuss på appen. \
Den er også kompatibel med macOS 26 Tahoe.

### Forbedret simulering av styreflate-rulling

- Rullesystemet kan nå simulere et tofingertrykk på styreflaten for å få applikasjoner til å stoppe rullingen.
    - Dette fikser et problem ved kjøring av iPhone- eller iPad-apper, der rullingen ofte fortsatte etter at brukeren valgte å stoppe.
- Fikset inkonsekvent simulering av å løfte fingrene fra styreflaten.
    - Dette kan ha forårsaket suboptimal oppførsel i noen situasjoner.



### macOS 26 Tahoe-kompatibilitet

Når du kjører macOS 26 Tahoe Beta, er appen nå brukbar, og det meste av brukergrensesnittet fungerer korrekt.



### Ytelsesforbedring

Forbedret ytelse for Klikk og dra til "Rull og naviger"-bevegelsen. \
I mine tester har CPU-bruken blitt redusert med ~50%!

**Bakgrunn**

Under "Rull og naviger"-bevegelsen tegner Mac Mouse Fix en falsk musepeker i et gjennomsiktig vindu, mens den virkelige musepekeren låses på plass. Dette sikrer at du kan fortsette å rulle UI-elementet du begynte å rulle på, uansett hvor langt du flytter musen.

Den forbedrede ytelsen ble oppnådd ved å slå av standard macOS-hendelseshåndtering på dette gjennomsiktige vinduet, som uansett ikke ble brukt.





### Feilrettinger

- Ignorerer nå rullehendelser fra Wacom-tegnebrett.
    - Tidligere forårsaket Mac Mouse Fix uregelmessig rulling på Wacom-brett, som rapportert av @frenchie1980 i GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Takk!)
    
- Fikset en feil der Swift Concurrency-koden, som ble introdusert som en del av det nye lisenssystemet i Mac Mouse Fix 3.0.4, ikke kjørte på riktig tråd.
    - Dette forårsaket krasj på macOS Tahoe, og det forårsaket sannsynligvis også andre sporadiske feil rundt lisensiering.
- Forbedret robustheten til koden som dekoder offline-lisenser.
    - Dette omgår et problem i Apples API-er som førte til at offline-lisensvalidering alltid feilet på min Intel Mac Mini. Jeg antar at dette skjedde på alle Intel Mac-er, og at det var grunnen til at "Gratisdagene er over"-feilen (som allerede ble adressert i 3.0.4) fortsatt oppstod for noen, som rapportert av @toni20k5267 i GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Tusen takk!)
        - Hvis du opplevde "Gratisdagene er over"-feilen, beklager jeg det! Du kan få refusjon [her](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### UX-forbedringer

- Deaktivert dialoger som ga trinnvise løsninger for macOS-feil som hindret brukere i å aktivere Mac Mouse Fix.
    - Disse problemene oppstod bare på macOS 13 Ventura og 14 Sonoma. Nå vises disse dialogene bare på de macOS-versjonene der de er relevante. 
    - Dialogene er også litt vanskeligere å utløse – tidligere dukket de noen ganger opp i situasjoner der de ikke var veldig nyttige.
    
- Lagt til en "Aktiver lisens"-lenke direkte på "Gratisdagene er over"-varslingen. 
    - Dette gjør aktivering av en Mac Mouse Fix-lisens enda mer problemfritt!

### Visuelle forbedringer

- Litt forbedret utseendet på "Programvareoppdatering"-vinduet. Nå passer det bedre med macOS 26 Tahoe. 
    - Dette ble gjort ved å tilpasse standardutseendet til "Sparkle 1.27.3"-rammeverket som Mac Mouse Fix bruker til å håndtere oppdateringer.
- Fikset problem der teksten nederst i Om-fanen noen ganger ble avskåret på kinesisk, ved å gjøre vinduet litt bredere.
- Fikset at teksten nederst i Om-fanen var litt av-sentrert.
- Fikset en feil som førte til at plassen under "Tastatursnarvei..."-alternativet i Knapper-fanen var for liten. 

### Endringer under panseret

- Fjernet avhengighet av "SnapKit"-rammeverket.
    - Dette reduserer størrelsen på appen litt fra 19,8 til 19,5 MB.
- Diverse andre små forbedringer i kodebasen.

*Redigert med utmerket hjelp fra Claude.*

---

Sjekk også ut forrige utgivelse [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).