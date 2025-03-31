Nézd meg, **mi volt az újdonság** a [3.0.0 Beta 3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-3) verzióban is!

---

A **3.0.0 Beta 4** új **"Alapértelmezések visszaállítása..." opciót** hoz, valamint számos **életminőség-javítást** és **hibajavítást**!

Íme **minden** ami **új**:

## 1. "Alapértelmezések visszaállítása..." opció

Most már van egy "**Alapértelmezések visszaállítása...**" gomb a "Gombok" fülön.
Ez még **magabiztosabbá** tesz a beállításokkal való **kísérletezés** során.

**2 alapértelmezett** beállítás érhető el:

1. Az "Alapértelmezett beállítás **5+ gombos** egerekhez" szuper hatékony és kényelmes. Tulajdonképpen **mindent** megtehetsz vele, amit egy **trackpaddel**. Mindezt a 2 **oldalsó gombbal**, ami pont ott van, ahol a **hüvelykujjad** pihen! De természetesen ez csak 5 vagy több gombos egereken érhető el.
2. Az "Alapértelmezett beállítás **3 gombos** egerekhez" még mindig lehetővé teszi a **legfontosabb** trackpad-funkciókat - még egy olyan egéren is, amelynek csak 3 gombja van.

Igyekeztem **okossá** tenni ezt a funkciót:

- Amikor először indítod el az MMF-et, **automatikusan kiválasztja** az **egeredhez legjobban illő** alapbeállítást.
- Amikor visszaállítod az alapértelmezéseket, a Mac Mouse Fix **megmutatja**, hogy milyen **egérmodellt** használsz és hány **gombja** van, így könnyen eldöntheted, melyik alapbeállítást használd. **Előre kiválasztja** az **egeredhez legjobban illő** alapbeállítást.
- Amikor **új egérre** váltasz, ami nem kompatibilis a jelenlegi beállításaiddal, egy felugró ablak a Gombok fülön **emlékeztet**, hogyan **töltheted be** az egeredhez ajánlott beállításokat!
- Az ehhez kapcsolódó **felhasználói felület** nagyon **egyszerű**, **szép** és **szépen animált**.

Remélem **hasznosnak** és **könnyen használhatónak** találod ezt a funkciót! De jelezd, ha bármilyen problémád van.
Valami **furcsa** vagy **nem intuitív**? A **felugró ablakok** **túl gyakran** vagy **nem megfelelő helyzetekben** jelennek meg? **Oszd meg velem** a tapasztalataidat!

## 2. A Mac Mouse Fix ideiglenesen ingyenes egyes országokban

Vannak **országok**, ahol a Mac Mouse Fix **fizetési szolgáltatója**, a Gumroad jelenleg **nem működik**.
A Mac Mouse Fix most **ingyenes** **ezekben az országokban**, amíg nem tudok alternatív fizetési módot biztosítani!

Ha olyan országban vagy, ahol ingyenes, erről **információt** találsz a **Névjegy fülön** és a **licenckulcs megadásakor**

Ha a te országodban **lehetetlen megvásárolni** a Mac Mouse Fix-et, de még **nem is ingyenes** - jelezd, és ingyenessé teszem az országodban is!

## 3. Itt az ideje a fordításnak!

A Beta 4-gyel **minden tervezett UI változtatást** implementáltam a Mac Mouse Fix 3-hoz. Így nem várhatók további nagy változtatások a felhasználói felületen a Mac Mouse Fix 3 megjelenéséig.

Ha eddig vártál, mert arra számítottál, hogy még változni fog a felület, akkor **most jött el az ideje**, hogy elkezdd **lefordítani** az alkalmazást a saját nyelvedre!

A fordítással kapcsolatos **további információkért** lásd a **[3.0.0 Beta 1 Release Notes](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-1.1) > 9. Internationalization** részt

## 4. Minden egyéb

A fent felsorolt változtatásokon kívül a Beta 4 számos további kisebb **hibajavítást**, **finomítást** és **életminőség-javítást** tartalmaz:

### UI

#### Hibajavítások

- Javítva az a hiba, ahol a Névjegy fülről a linkek újra és újra megnyíltak, ha bárhova kattintottál az ablakban. Köszönet [DingoBits](https://github.com/DingoBits) GitHub felhasználónak, aki javította ezt!
- Javítva néhány alkalmazáson belüli szimbólum helytelen megjelenítése régebbi macOS verziókon
- Görgetősávok elrejtve az Action Table-ben. Köszönet [marianmelinte93](https://github.com/marianmelinte93) GitHub felhasználónak, aki felhívta a figyelmemet erre a problémára [ebben a hozzászólásban](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366#discussioncomment-3728994)!
- Javítva az a probléma, ahol a funkciók automatikus újraengedélyezéséről szóló visszajelzés nem jelent meg macOS Monterey és régebbi verziókon, amikor megnyitottad az adott funkcióhoz tartozó fület a felhasználói felületen (miután kikapcsoltad az adott funkciót a menüsorból). Ismét köszönet [marianmelinte93](https://github.com/marianmelinte93)-nak, hogy felhívta a figyelmet a problémára.
- Hiányzó lokalizálhatóság és német fordítások hozzáadva a "Click to Scroll to Move Between Spaces" opcióhoz
- További kisebb lokalizálhatósági problémák javítva
- További hiányzó német fordítások hozzáadva
- A gombok rögzítéséről/feloldásáról szóló értesítések most megfelelően működnek, amikor egyes gombok rögzítve, mások pedig feloldva vannak egyidejűleg.

#### Fejlesztések

- "Click and Scroll for App Switcher" opció eltávolítva. Kissé bugos volt és nem hiszem, hogy nagyon hasznos lett volna.
- "Click and Scroll to Rotate" opció hozzáadva.
- A menüsorban található "Mac Mouse Fix" menü elrendezése finomítva.
- "Mac Mouse Fix megvásárlása" gomb hozzáadva a menüsorban található "Mac Mouse Fix" menühöz.
- Magyarázó szöveg hozzáadva a "Megjelenítés a menüsorban" opció alá. A cél az, hogy könnyebben felfedezhetővé váljon, hogy a menüsor elem használható a funkciók gyors ki- és bekapcsolására
- A "Köszönjük, hogy megvásároltad a Mac Mouse Fix-et" üzenetek a névjegy képernyőn most teljesen testreszabhatók a lokalizálók által.
- Javított útmutatások a lokalizálók számára
- Javított UI szövegek a próbaverzió lejáratával kapcsolatban
- Javított UI szövegek a Névjegy fülön
- Félkövér kiemelések hozzáadva néhány UI szöveghez az olvashatóság javítása érdekében
- Figyelmeztető üzenet hozzáadva a "Küldj nekem egy e-mailt" linkre kattintáskor a Névjegy fülön.
- Action Table rendezési sorrendje megváltoztatva. A Kattintás és Görgetés műveletek most a Kattintás és Húzás műveletek előtt jelennek meg. Ez természetesebbnek tűnik, mivel a táblázat sorai most az indítóik erőssége szerint vannak rendezve (Kattintás < Görgetés < Húzás).
- Az alkalmazás most frissíti az aktívan használt eszközt a felhasználói felülettel való interakció során. Ez hasznos, mivel a felhasználói felület egy része most az általad használt eszközön alapul. (Lásd az új "Alapértelmezések visszaállítása..." funkciót.)
- Értesítés jelenik meg arról, hogy mely gombok lettek rögzítve / már nincsenek rögzítve, amikor először indítod el az alkalmazást.
- További fejlesztések a gombok rögzítéséről/feloldásáról szóló értesítésekben
- Lehetetlenné vált a felesleges szóközök véletlen bevitele a licenckulcs aktiválásakor

### Egér

#### Hibajavítások

- Javított görgetés szimuláció a "fixed point deltas" megfelelő küldéséhez. Ez megoldja azt a problémát, ahol a görgetési sebesség túl lassú volt néhány alkalmazásban, mint például a Safari kikapcsolt smooth scrolling esetén.
- Javítva az a probléma, ahol a "Click and Drag for Mission Control & Spaces" funkció néha beragadt, amikor a számítógép lassú volt
- Javítva az a probléma, ahol a CPU-t folyamatosan használta a Mac Mouse Fix az egér mozgatásakor, miután használtad a "Click and Drag to Scroll & Navigate" funkciót

#### Fejlesztések

- Jelentősen javított görgetés-nagyítás válaszképesség a Chromium-alapú böngészőkben, mint a Chrome, Brave vagy Edge

### Háttérrendszer

#### Hibajavítások

- Javítva az a probléma, ahol a Mac Mouse Fix nem működött megfelelően, miután áthelyezted egy másik mappába, miközben engedélyezve volt
- Javítva néhány probléma a Mac Mouse Fix engedélyezésével kapcsolatban, miközben egy másik példány még engedélyezve volt. (Ez azért van, mert az Apple lehetővé tette számomra, hogy visszaváltoztassam a bundle ID-t "com.nuebling.mac-mouse-fixxx"-ről, amit a Beta 3-ban használtunk, az eredeti "com.nuebling.mac-mouse-fix"-re. Nem tudom, miért.)

#### Fejlesztések

- Ez és a jövőbeli béták részletesebb hibakeresési információkat fognak kiírni
- Háttérrendszer tisztítása és fejlesztések. Régi, 10.13 előtti kód eltávolítva. Keretrendszerek és függőségek tisztítva. A forráskód most könnyebben kezelhető, jövőbiztosabb.