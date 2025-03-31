Nézd meg a **remek változtatásokat** is a [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5) verzióban!


---

A **3.0.0 Beta 6** mélyreható optimalizációkat és finomításokat, a görgetési beállítások újragondolását, kínai fordításokat és még sok mást tartalmaz!

Íme az összes újdonság:

## 1. Mélyreható Optimalizációk

Ennél a Beta verziónál sok munkát fektettem abba, hogy kihozzam a maximumot a Mac Mouse Fix teljesítményéből. Most örömmel jelenthetem, hogy amikor a Beta 6-ban kattintasz az egérgombbal, az **2x** gyorsabb az előző beta verzióhoz képest! A görgetés pedig még ennél is **4x** gyorsabb!

A Beta 6-tal az MMF okosan ki is kapcsolja bizonyos részeit, hogy a lehető legjobban kímélje a processzort és az akkumulátort.

Például, ha jelenleg egy 3 gombos egeret használsz, de csak olyan gombokhoz állítottál be műveleteket, amelyek nincsenek az egereden (mint a 4-es és 5-ös gombok), a Mac Mouse Fix teljesen abbahagyja az egérgombok figyelését. Ez azt jelenti, hogy 0% CPU használat, amikor az egereddel kattintasz! Vagy amikor az MMF görgetési beállításai megegyeznek a rendszerével, a Mac Mouse Fix teljesen abbahagyja a görgő figyelését. Ez 0% CPU használatot jelent görgetéskor! De ha beállítod a Command (⌘)-Görgetés a Nagyításhoz funkciót, a Mac Mouse Fix elkezdi figyelni a görgő bemenetét - de csak amíg nyomva tartod a Command (⌘) billentyűt. És így tovább.
Tehát tényleg okos, és csak akkor használ processzort, amikor muszáj!

Ez azt jelenti, hogy az MMF most már nemcsak a legerősebb, legkönnyebben használható és legkifinomultabb egérmeghajtó Macre, hanem az egyik, ha nem a legoptimalizáltabb és leghatékonyabb is!

## 2. Csökkentett Alkalmazásméret

16 MB-tal a Beta 6 kb. 2x kisebb, mint a Beta 5!

Ez a régebbi macOS verziók támogatásának megszüntetésének mellékhatása.

## 3. Régebbi macOS Verziók Támogatásának Megszüntetése

Keményen próbálkoztam, hogy az MMF 3 megfelelően fusson a macOS 11 Big Sur előtti verziókon. De a munka mennyisége, ami ahhoz kellett volna, hogy kifinomultan működjön, túl nagy volt, így fel kellett adnom.

A jövőben a legkorábbi hivatalosan támogatott verzió a macOS 11 Big Sur lesz.

Az alkalmazás még mindig elindul régebbi verziókon, de vizuális és esetleg egyéb problémák lesznek. Az alkalmazás már nem fog elindulni a 10.14.4 előtti macOS verziókon. Ez teszi lehetővé, hogy 2x-esére csökkentsük az alkalmazás méretét, mivel a 10.14.4 a legkorábbi macOS verzió, amely modern Swift könyvtárakkal érkezik (lásd "Swift ABI Stability"), ami azt jelenti, hogy ezeknek a Swift könyvtáraknak már nem kell az alkalmazásban lenniük.

## 4. Görgetési Fejlesztések

A Beta 6 számos fejlesztést tartalmaz az MMF 3-ban bevezetett új görgetési rendszerek konfigurációjában és felhasználói felületében.

### Felhasználói Felület

- Jelentősen egyszerűsítettük és rövidítettük a Görgetés fül szövegeit. A "Görgetés" szó legtöbb említését eltávolítottuk, mivel a kontextusból következik.
- Átdolgoztuk a görgetés simaságának beállításait, hogy sokkal világosabbak legyenek és további lehetőségeket kínáljanak. Most választhatsz "Ki", "Normál" vagy "Magas" "Simaság" között, felváltva a régi "Tehetetlenséggel" kapcsolót. Szerintem ez sokkal világosabb, és helyet csinált a felületen az új "Trackpad Szimuláció" opciónak.
- Az új "Trackpad Szimuláció" opció kikapcsolása letiltja a gumiszalag effektust görgetés közben, megakadályozza az oldalak közötti görgetést Safariban és más alkalmazásokban, és még sok mást. Sok embert zavart ez, különösen azokat, akiknek szabadon pörgő görgőjük van, mint például néhány Logitech egéren, mint az MX Master, de mások élvezik, így úgy döntöttem, hogy opcióvá teszem. Remélem, a funkció bemutatása világos. Ha vannak javaslataid ezzel kapcsolatban, tudass róla.
- A "Természetes Görgetési Irány" opciót "Görgetési Irány Megfordítása" opcióra változtattuk. Ez azt jelenti, hogy a beállítás most megfordítja a rendszer görgetési irányát, és már nem független a rendszer görgetési irányától. Bár ez vitathatóan kissé rosszabb felhasználói élményt jelent, ez az új módszer lehetővé teszi néhány optimalizáció megvalósítását, és átláthatóbbá teszi a felhasználó számára, hogyan lehet teljesen kikapcsolni a Mac Mouse Fix-et görgetéshez.
- Javítottuk a görgetési beállítások és a módosított görgetés közötti kölcsönhatást számos különböző határesetben. Például a "Precíziós" opció már nem vonatkozik az "Asztali és Launchpad" művelethez tartozó "Kattintás és Görgetés" funkcióra, mivel itt inkább hátrány, mint segítség.
- Javítottuk a görgetési sebességet a "Kattintás és Görgetés" használatakor az "Asztali és Launchpad" vagy "Nagyítás Be vagy Ki" és más funkciókhoz.
- Eltávolítottuk a nem működő linket a rendszer görgetési sebesség beállításaihoz a görgetés fülön, amely a macOS 13.0 Ventura előtti verziókon volt jelen. Nem találtam módot a link működővé tételére, és nem is annyira fontos.

### Görgetési Élmény

- Javított animációs görbe a "Normál Simaság" esetén (korábban elérhető a "Tehetetlenség" kikapcsolásával). Ez simábbá és reagálóképesebbé teszi a dolgokat.
- Javítottuk az összes görgetési sebesség beállítás érzetét. A "Közepes" és a "Gyors" sebesség gyorsabb. Nagyobb a különbség az "Alacsony", "Közepes" és "Magas" sebességek között. A sebesség növekedése, ahogy gyorsabban mozgatod a görgőt, természetesebb és kényelmesebb érzést ad a "Precíziós" opció használatakor.
- A görgetési sebesség fokozódásának módja, ahogy egy irányban továbbra is görgetsz, természetesebb és fokozatosabb lesz. Új matematikai görbéket használok a gyorsulás modellezéséhez. A sebesség fokozódását is nehezebb lesz véletlenül aktiválni.
- Már nem növeljük a görgetési sebességet, amikor egy irányban továbbra is görgetsz a "macOS" görgetési sebesség használatakor.
- Korlátoztuk a görgetési animáció maximális idejét. Ha a görgetési animáció természetesen több időt venne igénybe, felgyorsul, hogy a maximális idő alatt maradjon. Így, amikor egy szabadon pörgő görgővel az oldal széléig görgetsz, az oldal tartalma nem mozog el olyan hosszú időre a képernyőről. Ez nem befolyásolja a normál görgetést nem szabadon pörgő görgővel.
- Javítottuk a gumiszalag effektus körüli néhány interakciót, amikor az oldal széléig görgetsz Safariban és más alkalmazásokban.
- Javítottuk azt a problémát, ahol a "Kattintás és Görgetés" és más görgetéssel kapcsolatos funkciók nem működtek megfelelően a Mac Mouse Fix nagyon régi preference pane verziójáról való frissítés után.
- Javítottuk azt a problémát, ahol az egypixeles görgetések késéssel kerültek elküldésre a "macOS" görgetési sebesség és a sima görgetés együttes használatakor.
- Javítottuk azt a hibát, ahol a görgetés még mindig nagyon gyors volt a Gyors Görgetés módosító elengedése után. Egyéb fejlesztések a görgetési sebesség átvitelével kapcsolatban az előző görgetési húzásokból.
- Javítottuk a görgetési sebesség növekedésének módját nagyobb kijelzőméretek esetén

## 5. Hitelesítés

A 3.0.0 Beta 6-tól kezdve a Mac Mouse Fix "Hitelesített" lesz. Ez azt jelenti, hogy nem lesznek többé üzenetek arról, hogy a Mac Mouse Fix potenciálisan "Rosszindulatú Szoftver" az alkalmazás első megnyitásakor.

Az alkalmazás hitelesítése évi 100 dollárba kerül. Mindig ellene voltam ennek, mivel ellenségesnek tűnt az ingyenes és nyílt forráskódú szoftverekkel szemben, mint a Mac Mouse Fix, és veszélyes lépésnek tűnt afelé, hogy az Apple ugyanúgy irányítsa és lezárja a Mac-et, mint az iOS-t. De a hitelesítés hiánya elég súlyos problémákhoz vezetett, beleértve [több olyan helyzetet](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114), ahol senki sem tudta használni az alkalmazást, amíg ki nem adtam egy új verziót. Mivel a Mac Mouse Fix most már fizetős lesz, úgy gondoltam, végre helyénvaló hitelesíteni az alkalmazást a könnyebb és stabilabb felhasználói élmény érdekében.

## 6. Kínai Fordítások

A Mac Mouse Fix most már elérhető kínaiul!
Pontosabban, elérhető:

- Hagyományos kínai
- Egyszerűsített kínai
- Kínai (Hong Kong)

Hatalmas köszönet @groverlynn-nek, aki biztosította az összes fordítást, frissítette őket a béták során és kommunikált velem. Nézd meg a pull request-jét itt: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Minden Egyéb

A fent felsorolt változtatásokon kívül a Beta 6 számos kisebb fejlesztést is tartalmaz.

- Eltávolítottunk több opciót a "Kattintás", "Kattintás és Tartás" és "Kattintás és Görgetés" Műveletekből, mert úgy gondoltam, hogy redundánsak, mivel ugyanaz a funkcionalitás más módon is elérhető, és ez jelentősen letisztítja a menüket. Visszahozzuk ezeket az opciókat, ha az emberek panaszkodnak. Tehát ha hiányolod ezeket az opciókat - kérlek, panaszkodj.
- A Kattintás és Húzás iránya most már megegyezik a trackpad húzási irányával akkor is, ha a "Természetes görgetés" ki van kapcsolva a Rendszerbeállítások > Trackpad alatt. Korábban a Kattintás és Húzás mindig úgy viselkedett, mintha a trackpaden húznál bekapcsolt "Természetes görgetés" mellett.
- Javítottuk azt a problémát, ahol a kurzor eltűnt, majd máshol jelent meg újra, amikor a "Kattintás és Húzás" Műveletet használtad képernyőfelvétel közben vagy a DisplayLink szoftver használatakor.
- Javítottuk a "+" középre igazítását a "+"-Mezőben a Gombok fülön
- Több vizuális fejlesztés a gombok fülön. A "+"-Mező és a Művelet Táblázat színpalettáját átdolgoztuk, hogy helyesen nézzen ki a macOS "Háttérkép színezésének engedélyezése az ablakokban" opció használatakor. A Művelet Táblázat szegélyei most átlátszó színűek, ami dinamikusabb megjelenést biztosít és alkalmazkodik a környezetéhez.
- Úgy állítottuk be, hogy amikor sok műveletet adsz hozzá a művelet táblázathoz és a Mac Mouse Fix ablak növekszik, pontosan akkorára nő, mint a képernyő (vagy a képernyő mínusz a dock, ha nincs engedélyezve a dock elrejtése), majd megáll. Ha még több műveletet adsz hozzá, a művelet táblázat görgethetővé válik.
- Ez a Beta most már támogat egy új fizetési módot, ahol amerikai dollárban vásárolhatsz licencet a hirdetett módon. Korábban csak euróban lehetett licencet vásárolni. A régi eurós licencek természetesen továbbra is támogatottak lesznek.
- Javítottuk azt a problémát, ahol a lendületes görgetés néha nem indult el a "Görgetés és Navigálás" funkció használatakor.
- Amikor a Mac Mouse Fix ablak átméretezi magát egy fülváltás során, most újrapozicionálja magát, hogy ne fedje át a Dock-ot
- Javítottuk a villogást néhány UI elemen, amikor a Gombok fülről másik fülre váltasz
- Javítottuk a "+"-Mező animációjának megjelenését a bemenet rögzítése után. Különösen a Ventura előtti macOS verziókon, ahol a "+"-Mező árnyéka hibásnak tűnt az animáció során.
- Kikapcsoltuk azokat az értesítéseket, amelyek felsorolják a Mac Mouse Fix által rögzített/már nem rögzített gombokat, és amelyek az alkalmazás első indításakor vagy egy előbeállítás betöltésekor jelentek meg. Úgy gondoltam, hogy ezek az üzenetek zavaróak és kissé túlterhelőek, és nem igazán hasznosak ezekben a helyzetekben.
- Átdolgoztuk az Accessibility Hozzáférés Engedélyezése képernyőt. Most már közvetlenül megmutatja az információt arról, hogy miért van szüksége a Mac Mouse Fix-nek Accessibility hozzáférésre, ahelyett, hogy a weboldalra irányítana, és egy kicsit világosabb és vizuálisan vonzóbb elrendezést kapott.
- Frissítettük az Elismerések linket az About fülön.
- Javítottuk a hibaüzeneteket, amikor a Mac Mouse Fix nem engedélyezhető, mert egy másik verzió van jelen a rendszeren. Az üzenet most egy lebegő figyelmeztető ablakban jelenik meg, amely mindig a többi ablak tetején marad, amíg el nem utasítják, a Toast Értesítés helyett, amely eltűnik, ha bárhova kattintasz. Ez megkönnyíti a javasolt megoldási lépések követését.
- Javítottunk néhány problémát a markdown megjelenítéssel kapcsolatban a Ventura előtti macOS verziókon. Az MMF most egy egyedi markdown megjelenítési megoldást használ minden macOS verzióhoz, beleértve a Venturát is. Korábban egy Venturában bevezetett rendszer API-t használtunk, de ez következetlenségekhez vezetett. A markdown-t linkek és kiemelések hozzáadására használjuk a felhasználói felületen.
- Finomítottuk az accessibility hozzáférés engedélyezése körüli interakciókat.
- Javítottuk azt a problémát, ahol az alkalmazás ablaka néha tartalom nélkül nyílt meg, amíg át nem váltottál valamelyik fülre.
- Javítottuk azt a problémát a "+"-Mezővel kapcsolatban, ahol néha nem tudtál új műveletet hozzáadni, annak ellenére, hogy a lebegő effektus jelezte, hogy beléphetsz egy műveletbe.
- Javítottunk egy holtpontot és több kisebb problémát, amely néha akkor fordult elő, amikor az egérmutatót a "+"-Mezőn belül mozgattad
- Javítottuk azt a problémát, ahol egy felugró ablak, amely a Gombok fülön jelenik meg, amikor az egered nem tűnik megfelelőnek az aktuális gomb beállításokhoz, néha teljesen félkövér szöveggel jelent meg.
- Frissítettük az összes említést a régi MIT licencről az új MMF licencre. Az új fájlok, amelyeket a projekthez hozunk létre, most egy automatikusan generált fejlécet tartalmaznak, amely említi az MMF licencet.
- A Gombok fülre váltás most engedélyezi az MMF-et Görgetéshez. Különben nem tudnád rögzíteni a Kattintás és Görgetés gesztusokat.
- Javítottunk néhány problémát, ahol a gombnevek nem megfelelően jelentek meg a Művelet Táblázatban bizonyos helyzetekben.
- Javítottuk azt a hibát, ahol a próbaverzió szakasz az About képernyőn hibásan nézett ki, amikor megnyitottad az alkalmazást, majd átváltottál a próbaverzió fülre a próbaidő lejárta után.
- Javítottuk azt a hibát, ahol a Licenc Aktiválása link a próbaverzió szakaszban az About Fülön néha nem reagált a kattintásokra.
- Javítottuk a memóriaszivárgást a "Kattintás és Húzás" a "Spaces & Mission Control" funkció használatakor.
- Engedélyeztük a Hardened runtime-ot a fő Mac Mouse Fix alkalmazáson, javítva a biztonságot
- Sok kódtisztítás, projekt átszervezés
- Több összeomlás javítása
- Több memóriaszivárgás javítása
- Különböző kis UI szöveg finomítások
- Több belső rendszer átdolgozása is javította a robusztusságot és a viselkedést határesetekben

## 8. Hogyan Segíthetsz

Segíthetsz az **ötleteid**, **problémáid** és **visszajelzéseid** megosztásával!

Az **ötletek** és **problémák** megosztásának legjobb helye a [Visszajelzés Asszisztens](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
A **gyors**, strukturálatlan visszajelzések legjobb helye a [Visszajelzés Beszélgetés](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Ezeket a helyeket az alkalmazáson belül is elérheted az "**ⓘ About**" fülön.

**Köszönjük**, hogy segítesz a Mac Mouse Fix-et a lehető legjobbá tenni! 🙌:)