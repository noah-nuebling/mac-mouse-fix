A Mac Mouse Fix **2.2.4** mostantól hitelesített! Emellett néhány hibajavítást és egyéb fejlesztést is tartalmaz.

### **Hitelesítés**

A Mac Mouse Fix 2.2.4 mostantól Apple által 'hitelesített'. Ez azt jelenti, hogy többé nem jelennek meg üzenetek arról, hogy a Mac Mouse Fix esetlegesen 'Rosszindulatú Szoftver' lenne, amikor először nyitod meg az alkalmazást.

#### Háttér

Az alkalmazás hitelesítése évi 100 dollárba kerül. Mindig is elleneztem ezt, mivel úgy éreztem, hogy ez ellenséges a Mac Mouse Fix-hez hasonló ingyenes és nyílt forráskódú szoftverekkel szemben, és veszélyes lépésnek tűnt az Apple részéről a Mac zárt rendszerré alakítása felé, ahogy azt az iPhone-okkal és iPadekkel is teszik. A hitelesítés hiánya azonban különböző problémákhoz vezetett, beleértve az [alkalmazás megnyitásának nehézségeit](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114), sőt [több olyan helyzetet](https://github.com/noah-nuebling/mac-mouse-fix/issues/95), ahol senki sem tudta használni az alkalmazást, amíg ki nem adtam egy új verziót.

A Mac Mouse Fix 3 esetében végül úgy gondoltam, hogy megfelelő az évi 100 dollárt kifizetni a hitelesítésért, mivel a Mac Mouse Fix 3 már monetizált. ([További információ](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Most a Mac Mouse Fix 2 is megkapja a hitelesítést, ami egyszerűbb és stabilabb felhasználói élményt eredményez.

### **Hibajavítások**

- Javítva lett egy probléma, ahol a kurzor eltűnt, majd máshol jelent meg, amikor 'Kattintás és Húzás' műveletet használtál képernyőfelvétel közben vagy a [DisplayLink](https://www.synaptics.com/products/displaylink-graphics) szoftver használata során.
- Javítva lett egy probléma a Mac Mouse Fix engedélyezésével macOS 10.14 Mojave és esetleg régebbi macOS verziók alatt.
- Fejlesztett memóriakezelés, potenciálisan javítva a 'Mac Mouse Fix Helper' alkalmazás összeomlását, ami akkor fordult elő, amikor leválasztottál egy egeret a számítógépedről. Lásd a [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771) beszélgetést.

### **Egyéb fejlesztések**

- Az ablak, amely tájékoztat a Mac Mouse Fix új verziójának elérhetőségéről, most már támogatja a JavaScriptet. Ez lehetővé teszi, hogy a frissítési jegyzetek szebbek és könnyebben olvashatók legyenek. Például a frissítési jegyzetek most már megjeleníthetnek [Markdown Figyelmeztetéseket](https://github.com/orgs/community/discussions/16925) és egyebeket.
- Eltávolítottuk a https://macmousefix.com/about/ oldalra mutató linket a "Hozzáférési jogok megadása a Mac Mouse Fix Helper számára" képernyőről. Ez azért történt, mert az About oldal már nem létezik, és egyelőre a [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix) helyettesíti.
- Ez a kiadás már tartalmazza a dSYM fájlokat, amelyeket bárki használhat a Mac Mouse Fix 2.2.4 összeomlási jelentéseinek dekódolásához.
- Néhány háttérbeli tisztogatás és fejlesztés.

---

Nézd meg az előző [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3) kiadást is.