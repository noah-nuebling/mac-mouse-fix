Mac Mouse Fix **2.2.1** ger fullt **stöd för macOS Ventura** bland andra ändringar.

### Ventura-stöd!
Mac Mouse Fix har nu fullt stöd för och känns naturligt i macOS 13 Ventura.
Särskilt tack till [@chamburr](https://github.com/chamburr) som hjälpte till med Ventura-stödet i GitHub-ärende [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Ändringar inkluderar:

- Uppdaterat gränssnittet för att bevilja åtkomst till Tillgänglighet för att återspegla Venturas nya Systeminställningar
- Mac Mouse Fix kommer att visas korrekt under Venturas nya meny **Systeminställningar > Inloggningsobjekt**
- Mac Mouse Fix kommer att reagera korrekt när det inaktiveras under **Systeminställningar > Inloggningsobjekt**

### Avslutat stöd för äldre macOS-versioner

Tyvärr låter Apple dig bara utveckla _för_ macOS 10.13 **High Sierra och senare** när du utvecklar _från_ macOS 13 Ventura.

Så den **lägsta versionen som stöds** har höjts från 10.11 El Capitan till 10.13 High Sierra.

### Buggfixar

- Åtgärdade ett problem där Mac Mouse Fix ändrar scrollningsbeteendet för vissa **ritplattor**. Se GitHub-ärende [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Åtgärdade ett problem där **kortkommandon** som innehåller 'A'-tangenten inte kunde spelas in. Fixar GitHub-ärende [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Åtgärdade ett problem där vissa **knappomkopplingar** inte fungerade korrekt vid användning av en icke-standardiserad tangentbordslayout.
- Åtgärdade en krasch i '**App-specifika inställningar**' när man försökte lägga till en app utan ett 'Bundle ID'. Kan hjälpa med GitHub-ärende [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Åtgärdade en krasch när man försökte lägga till appar utan namn i '**App-specifika inställningar**'. Löser GitHub-ärende [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Särskilt tack till [jeongtae](https://github.com/jeongtae) som var till stor hjälp med att lista ut problemet!
- Fler små buggfixar och förbättringar under huven.