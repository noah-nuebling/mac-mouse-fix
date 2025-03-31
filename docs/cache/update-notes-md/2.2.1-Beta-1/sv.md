### Ventura-stöd!
Mac Mouse Fix har nu fullt stöd för macOS 13 Ventura.
Särskilt tack till [@chamburr](https://github.com/chamburr) som hjälpte till med Ventura-stödet i GitHub-ärende [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

### Avslutat stöd för äldre macOS-versioner

Tyvärr tillåter Apple endast utveckling _för_ macOS 10.13 **High Sierra och senare** när man utvecklar _från_ macOS 13 Ventura.

Så den **lägsta versionen som stöds** har höjts från 10.11 El Capitan till 10.13 High Sierra.

Jag är ledsen för detta. Men för att muntra upp dig finns det en avslappnad nyckelpiga i nästa avsnitt.

### Buggfixar 🐞
- Åtgärdade en krasch i '**App-specifika inställningar**' när man försökte lägga till en app utan ett 'Bundle ID'. Kan hjälpa med GitHub-ärendena [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289) och [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241).
- Åtgärdade ett problem där Mac Mouse Fix ändrar scrollningsbeteendet för vissa **ritplattor**. Se GitHub-ärende [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Åtgärdade ett problem där **kortkommandon** som innehåller 'A'-tangenten inte kunde spelas in. Fixar GitHub-ärende [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Åtgärdade ett problem där vissa knapp**omkopplingar** inte fungerade korrekt när man använder en icke-standardiserad tangentbordslayout.
- **Andra** mindre fixar och visuella förbättringar.