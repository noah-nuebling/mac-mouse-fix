**ℹ️ Megjegyzés a Mac Mouse Fix 2 felhasználóknak**

A Mac Mouse Fix 3 bevezetésével az alkalmazás árazási modellje megváltozott:

- **Mac Mouse Fix 2**\
Továbbra is 100%-ban ingyenes marad, és tervezem a támogatását.\
**Hagyd ki ezt a frissítést**, ha továbbra is a Mac Mouse Fix 2-t szeretnéd használni. A Mac Mouse Fix 2 legújabb verzióját [itt](https://redirect.macmousefix.com/?target=mmf2-latest) töltheted le.
- **Mac Mouse Fix 3**\
30 napig ingyenes, utána néhány dollárba kerül.\
**Frissíts most** a Mac Mouse Fix 3-ra!

A Mac Mouse Fix 3 árazásáról és funkcióiról többet megtudhatsz az [új weboldalon](https://macmousefix.com/).

Köszönöm, hogy a Mac Mouse Fix-et használod! :)

---

**ℹ️ Megjegyzés a Mac Mouse Fix 3 vásárlóknak**

Ha véletlenül frissítettél a Mac Mouse Fix 3-ra anélkül, hogy tudtad volna, hogy már nem ingyenes, szeretnék felajánlani egy [visszatérítést](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

A Mac Mouse Fix 2 legújabb verziója **teljesen ingyenes** marad, és [itt](https://redirect.macmousefix.com/?target=mmf2-latest) töltheted le.

Sajnálom a kellemetlenséget, és remélem, mindenki elfogadhatónak találja ezt a megoldást!

---

A Mac Mouse Fix **3.0.3** készen áll a macOS 15 Sequoia-ra. Emellett javít néhány stabilitási problémát és több kisebb fejlesztést tartalmaz.

### macOS 15 Sequoia támogatás

Az alkalmazás most már megfelelően működik macOS 15 Sequoia alatt!

- A legtöbb UI animáció nem működött megfelelően macOS 15 Sequoia alatt. Most már minden rendben működik!
- A forráskód most már fordítható macOS 15 Sequoia alatt. Korábban problémák voltak a Swift fordítóval, ami megakadályozta az alkalmazás fordítását.

### Görgetési összeomlások kezelése

A Mac Mouse Fix 3.0.2 óta [több jelentés](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) érkezett arról, hogy a Mac Mouse Fix időszakosan kikapcsolja, majd újra engedélyezi magát görgetés közben. Ezt a 'Mac Mouse Fix Helper' háttéralkalmazás összeomlása okozta. Ez a frissítés megpróbálja kijavítani ezeket az összeomlásokat a következő változtatásokkal:

- A görgetési mechanizmus megpróbál helyreállni és tovább működni összeomlás helyett, amikor azzal a határesettel találkozik, ami vélhetően ezeket az összeomlásokat okozta.
- Általánosságban megváltoztattam a váratlan állapotok kezelését az alkalmazásban: Ahelyett, hogy azonnal összeomlana, az alkalmazás most sok esetben megpróbál helyreállni a váratlan állapotokból.

    - Ez a változtatás hozzájárul a fent leírt görgetési összeomlások javításához. Más összeomlásokat is megelőzhet.

Megjegyzés: Sosem tudtam reprodukálni ezeket az összeomlásokat a saját gépemen, és még mindig nem vagyok biztos benne, mi okozta őket, de a kapott jelentések alapján ennek a frissítésnek meg kellene akadályoznia az összeomlásokat. Ha még mindig tapasztalsz összeomlásokat görgetés közben, vagy ha tapasztaltál összeomlásokat a 3.0.2 alatt, értékes lenne, ha megosztanád tapasztalataidat és diagnosztikai adataidat a GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) problémában. Ez segítene megérteni a problémát és fejleszteni a Mac Mouse Fix-et. Köszönöm!

### Görgetési akadozások kezelése

A 3.0.2-ben változtatásokat végeztem abban, ahogy a Mac Mouse Fix görgetési eseményeket küld a rendszernek, hogy csökkentsem az Apple VSync API-k problémái miatt valószínűleg fellépő görgetési akadozásokat.

Azonban alaposabb tesztelés és visszajelzések után úgy tűnik, hogy a 3.0.2-ben lévő új mechanizmus egyes esetekben simábbá teszi a görgetést, más esetekben viszont akadozóbbá. Különösen Firefox-ban észrevehetően rosszabb volt.\
Összességében nem volt egyértelmű, hogy az új mechanizmus valóban javította-e a görgetési akadozásokat minden területen. Emellett lehet, hogy hozzájárult a fent leírt görgetési összeomlásokhoz is.

Ezért kikapcsoltam az új mechanizmust, és visszaállítottam a VSync mechanizmust a görgetési eseményeknél arra, ahogy a Mac Mouse Fix 3.0.0 és 3.0.1 verziókban volt.

További információért lásd a GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) problémát.

### Visszatérítés

Sajnálom a 3.0.1 és 3.0.2 görgetési változtatásaival kapcsolatos problémákat. Nagyon alábecsültem az ezzel járó problémákat, és lassan reagáltam ezekre a problémákra. Igyekszem tanulni ebből a tapasztalatból és óvatosabb lenni az ilyen változtatásokkal a jövőben. Szeretnék visszatérítést felajánlani minden érintettnek. Csak kattints [ide](https://redirect.macmousefix.com/?target=mmf-apply-for-refund), ha érdekel.

### Okosabb frissítési mechanizmus

Ezek a változtatások a Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) és [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5) verzióiból lettek áthozva. Nézd meg a kiadási jegyzeteiket, hogy többet megtudj a részletekről. Íme egy összefoglaló:

- Van egy új, okosabb mechanizmus, ami eldönti, melyik frissítést mutassa a felhasználónak.
- Áttértünk a Sparkle 1.26.0 frissítési keretrendszerről a legújabb Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3)-ra.
- Az ablak, ami tájékoztat az új Mac Mouse Fix verzió elérhetőségéről, most már támogatja a JavaScriptet, ami lehetővé teszi a frissítési jegyzetek szebb formázását.

### Egyéb fejlesztések és hibajavítások

- Javítva egy probléma, ahol az alkalmazás ára és kapcsolódó információk helytelenül jelentek meg a 'Névjegy' fülön bizonyos esetekben.
- Javítva egy probléma, ahol a sima görgetés képernyő-frissítési rátával való szinkronizálási mechanizmusa nem működött megfelelően több kijelző használata esetén.
- Sok kisebb háttérbeli tisztogatás és fejlesztés.

---

Nézd meg az előző [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2) kiadást is.