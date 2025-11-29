A Mac Mouse Fix **3.0.3** készen áll a macOS 15 Sequoia-ra. Emellett javít néhány stabilitási problémát és több kisebb fejlesztést is tartalmaz.

### macOS 15 Sequoia támogatás

Az alkalmazás most már megfelelően működik macOS 15 Sequoia alatt!

- A legtöbb felhasználói felület animáció hibás volt macOS 15 Sequoia alatt. Most már minden újra megfelelően működik!
- A forráskód most már fordítható macOS 15 Sequoia alatt. Korábban a Swift fordítóval kapcsolatos problémák akadályozták az alkalmazás fordítását.

### Görgetési összeomlások kezelése

A Mac Mouse Fix 3.0.2 óta [több bejelentés](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) érkezett arról, hogy a Mac Mouse Fix időszakosan kikapcsol és újra bekapcsol görgetés közben. Ezt a 'Mac Mouse Fix Helper' háttéralkalmazás összeomlásai okozták. Ez a frissítés megpróbálja javítani ezeket az összeomlásokat a következő változtatásokkal:

- A görgetési mechanizmus megpróbál helyreállni és tovább működni összeomlás helyett, amikor találkozik azzal a szélsőséges esettel, amely úgy tűnik, ezekhez az összeomlásokhoz vezetett.
- Megváltoztattam azt a módot, ahogyan a váratlan állapotokat az alkalmazás általánosságban kezeli: Azonnali összeomlás helyett az alkalmazás most sok esetben megpróbál helyreállni a váratlan állapotokból.
    
    - Ez a változtatás hozzájárul a fent leírt görgetési összeomlások javításához. Más összeomlásokat is megakadályozhat.

Megjegyzés: Soha nem tudtam reprodukálni ezeket az összeomlásokat a saját gépemen, és még mindig nem vagyok biztos abban, hogy mi okozta őket, de a kapott bejelentések alapján ez a frissítés meg kell, hogy akadályozza az összeomlásokat. Ha továbbra is tapasztalsz összeomlásokat görgetés közben, vagy *tapasztaltál* összeomlásokat a 3.0.2 alatt, értékes lenne, ha megosztanád a tapasztalataidat és diagnosztikai adataidat a GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988)-ban. Ez segítene megérteni a problémát és javítani a Mac Mouse Fixet. Köszönöm!

### Görgetési akadozások kezelése

A 3.0.2-ben változtattam azon, ahogyan a Mac Mouse Fix görgetési eseményeket küld a rendszernek, hogy csökkentsem az Apple VSync API-jaival kapcsolatos problémák által valószínűleg okozott görgetési akadozásokat.

Azonban kiterjedtebb tesztelés és visszajelzések után úgy tűnik, hogy az új mechanizmus a 3.0.2-ben bizonyos helyzetekben simábbá teszi a görgetést, másokban viszont akadozóbbá. Különösen a Firefoxban tűnt észrevehetően rosszabbnak. \
Összességében nem volt egyértelmű, hogy az új mechanizmus valóban javította-e a görgetési akadozásokat általánosan. Emellett hozzájárulhatott a fent leírt görgetési összeomlásokhoz is.

Ezért letiltottam az új mechanizmust és visszaállítottam a VSync mechanizmust a görgetési eseményekhez arra, ahogy a Mac Mouse Fix 3.0.0-ban és 3.0.1-ben volt.

További információért lásd a GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875)-öt.

### Visszatérítés

Sajnálom a 3.0.1 és 3.0.2 görgetési változtatásaival kapcsolatos kellemetlenségeket. Nagymértékben alábecsültem az ezzel járó problémákat, és lassú voltam ezeknek a problémáknak a kezelésében. Mindent megteszek, hogy tanuljak ebből a tapasztalatból és óvatosabb legyek az ilyen változtatásokkal a jövőben. Szeretnék visszatérítést is felajánlani mindenkinek, akit érintett. Csak kattints [ide](https://redirect.macmousefix.com/?target=mmf-apply-for-refund), ha érdekel.

### Okosabb frissítési mechanizmus

Ezek a változtatások a Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) és [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5) verziókból kerültek át. Nézd meg a kiadási jegyzeteiket, hogy többet megtudj a részletekről. Itt egy összefoglaló:

- Van egy új, okosabb mechanizmus, amely eldönti, melyik frissítést mutassa a felhasználónak.
- Átváltottam a Sparkle 1.26.0 frissítési keretrendszerről a legújabb Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3)-ra.
- Az az ablak, amelyet az alkalmazás megjelenít, hogy tájékoztasson arról, hogy a Mac Mouse Fix új verziója elérhető, most támogatja a JavaScriptet, ami szebb formázást tesz lehetővé a frissítési jegyzetekhez.

### Egyéb fejlesztések és hibajavítások

- Javítottam egy problémát, ahol az alkalmazás ára és a kapcsolódó információk helytelenül jelentek meg a 'Névjegy' fülön bizonyos esetekben.
- Javítottam egy problémát, ahol a sima görgetés megjelenítési frissítési sebességgel való szinkronizálásának mechanizmusa nem működött megfelelően több kijelző használata közben.
- Rengeteg kisebb háttérbeli tisztítás és fejlesztés.

---

Nézd meg az előző kiadást is: [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).