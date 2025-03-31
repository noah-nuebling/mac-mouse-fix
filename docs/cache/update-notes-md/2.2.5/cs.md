Mac Mouse Fix **2.2.5** přináší vylepšení mechanismu aktualizací a je připraven na macOS 15 Sequoia!

### Nový aktualizační framework Sparkle

Mac Mouse Fix používá aktualizační framework [Sparkle](https://sparkle-project.org/) pro zajištění skvělého zážitku z aktualizací.

S verzí 2.2.5 Mac Mouse Fix přechází ze Sparkle 1.26.0 na nejnovější Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), který obsahuje bezpečnostní opravy, vylepšení lokalizace a další změny.

### Chytřejší mechanismus aktualizací

Existuje nový mechanismus, který rozhoduje o tom, jaká aktualizace se uživateli zobrazí. Chování se změnilo v těchto ohledech:

1. Po přeskočení **hlavní** aktualizace (například 2.2.5 -> 3.0.0) budete stále dostávat oznámení o nových **vedlejších** aktualizacích (například 2.2.5 -> 2.2.6).
    - To vám umožní snadno zůstat na Mac Mouse Fix 2 a přitom dostávat aktualizace, jak bylo diskutováno v GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Místo zobrazení aktualizace na nejnovější verzi vám Mac Mouse Fix nyní ukáže aktualizaci na první verzi nejnovější hlavní verze.
    - Příklad: Pokud používáte MMF 2.2.5 a MMF 3.4.5 je nejnovější verze, aplikace vám nyní ukáže první verzi MMF 3 (3.0.0) místo nejnovější verze (3.4.5). Tímto způsobem všichni uživatelé MMF 2.2.5 uvidí seznam změn MMF 3.0.0 před přechodem na MMF 3.
    - Diskuze:
        - Hlavní motivací je, že začátkem tohoto roku mnoho uživatelů MMF 2 aktualizovalo přímo z MMF 2 na MMF 3.0.1 nebo 3.0.2. Protože nikdy neviděli seznam změn 3.0.0, přišli o informace o změnách v cenách mezi MMF 2 a MMF 3 (MMF 3 už není 100% zdarma). Takže když MMF 3 náhle oznámil, že je třeba zaplatit za další používání aplikace, někteří byli - pochopitelně - trochu zmatení a rozrušení.
        - Nevýhoda: Pokud chcete jen aktualizovat na nejnovější verzi, budete nyní v některých případech muset aktualizovat dvakrát. Je to mírně neefektivní, ale mělo by to stále trvat jen několik sekund. A protože to dělá změny mezi hlavními verzemi mnohem transparentnější, myslím, že je to rozumný kompromis.

### Podpora macOS 15 Sequoia

Mac Mouse Fix 2.2.5 bude skvěle fungovat na novém macOS 15 Sequoia - stejně jako 2.2.4.

---

Podívejte se také na předchozí verzi [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Pokud máte potíže s povolením Mac Mouse Fix po aktualizaci, podívejte se prosím na ['Průvodce povolením Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*