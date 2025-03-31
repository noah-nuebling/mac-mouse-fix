A Mac Mouse Fix **2.2.1** teljes **macOS Ventura támogatást** és egyéb változtatásokat kínál.

### Ventura támogatás!
A Mac Mouse Fix mostantól teljes mértékben támogatja és natív módon működik macOS 13 Venturán.
Külön köszönet [@chamburr](https://github.com/chamburr)-nak, aki segített a Ventura támogatással a GitHub [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297) hibajegyben.

Változások:

- Frissült a Kisegítő lehetőségek hozzáférés felülete, hogy tükrözze az új Ventura Rendszerbeállításokat
- A Mac Mouse Fix megfelelően jelenik meg a Ventura új **Rendszerbeállítások > Bejelentkezési elemek** menüjében
- A Mac Mouse Fix megfelelően reagál, ha letiltják a **Rendszerbeállítások > Bejelentkezési elemek** alatt

### Régebbi macOS verziók támogatásának megszüntetése

Sajnos az Apple csak akkor engedi a macOS 10.13 **High Sierra és újabb** verziókra való fejlesztést, ha macOS 13 Venturáról fejlesztünk.

Így a **minimálisan támogatott verzió** 10.11 El Capitanról 10.13 High Sierrára emelkedett.

### Hibajavítások

- Javítva egy probléma, ahol a Mac Mouse Fix megváltoztatta néhány **rajztábla** görgetési viselkedését. Lásd GitHub [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249) hibajegy.
- Javítva egy probléma, ahol az 'A' billentyűt tartalmazó **billentyűparancsokat** nem lehetett rögzíteni. Javítja a GitHub [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275) hibajegyet.
- Javítva egy probléma, ahol néhány **gomb-újratérképezés** nem működött megfelelően nem standard billentyűzetkiosztás használatakor.
- Javítva egy összeomlás az '**Alkalmazás-specifikus beállítások**' menüben, amikor 'Bundle ID' nélküli alkalmazást próbáltak hozzáadni. Segíthet a GitHub [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289) hibajeggyel.
- Javítva egy összeomlás, ami akkor történt, amikor név nélküli alkalmazásokat próbáltak hozzáadni az '**Alkalmazás-specifikus beállításokhoz**'. Megoldja a GitHub [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241) hibajegyet. Külön köszönet [jeongtae](https://github.com/jeongtae)-nek, aki nagyon segítőkész volt a probléma feltárásában!
- További kisebb hibajavítások és háttérbeli fejlesztések.