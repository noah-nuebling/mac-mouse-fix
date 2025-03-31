Nézd meg a **remek fejlesztéseket** is, amiket a [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6) hozott!


---

A **3.0.0 Beta 7** számos kisebb fejlesztést és hibajavítást tartalmaz.

Íme az összes újdonság:

**Fejlesztések**

- Hozzáadtuk a **koreai fordításokat**. Nagy köszönet @jeongtae-nek! (Megtalálod a [GitHubon](https://github.com/jeongtae))
- A 'Simaság: Magas' opcióval a **görgetés** **még simább** lett azáltal, hogy a sebesség csak fokozatosan változik, nem pedig hirtelen ugrásokkal, ahogy mozgatod a görgőt. Ez simábbá és szemmel könnyebben követhetővé teszi a görgetést anélkül, hogy csökkentené a reakcióképességet. A 'Simaság: Magas' opcióval történő görgetés körülbelül 30%-kal több CPU-t használ, az én gépemen 1.2%-ról 1.6%-ra nőtt a folyamatos görgetés során. Így a görgetés továbbra is nagyon hatékony, és remélem, ez senkinek nem okoz majd problémát. Nagy köszönet a [MOS](https://mos.caldis.me/)-nak, amely inspirálta ezt a funkciót, és amelynek 'Scroll Monitor'-ját használtam a funkció megvalósításához.
- A Mac Mouse Fix most már **minden forrásból kezeli a gombbemeneteket**. Korábban a Mac Mouse Fix csak az általa felismert egerek bemeneteit kezelte. Azt gondolom, ez segíthet bizonyos egerek kompatibilitásán szélsőséges esetekben, például Hackintosh használatakor, de ez azt is jelenti, hogy a Mac Mouse Fix más alkalmazások által mesterségesen generált gombbemeneteket is észlel, ami más szélsőséges esetekben problémákhoz vezethet. Jelezd, ha ez bármilyen problémát okoz számodra, és a jövőbeli frissítésekben foglalkozni fogok vele.
- Finomítottuk az 'Asztalt és Launchpadet' megjelenítő 'Kattintás és görgetés', valamint a 'Terek közötti mozgáshoz' használt 'Kattintás és görgetés' gesztusok érzetét és kidolgozottságát.
- Most már figyelembe vesszük a nyelv információsűrűségét az **értesítések megjelenítési idejének** kiszámításakor. Korábban az értesítések csak nagyon rövid ideig maradtak láthatóak a magas információsűrűségű nyelveken, mint a kínai vagy a koreai.
- Engedélyeztük a **különböző gesztusokat** a **Terek** közötti mozgáshoz, a **Mission Control** megnyitásához vagy az **App Exposé** megnyitásához. A Beta 6-ban kísérletképpen csak a 'Kattintás és húzás' gesztuson keresztül tettem elérhetővé ezeket a műveleteket, hogy lássam, hány embert érdekel valójában, hogy más módon is hozzáférhessen ezekhez a műveletekhez. Úgy tűnik, hogy néhányan igen, így most újra lehetővé tettem, hogy ezeket a műveleteket egy egyszerű 'Kattintással' vagy 'Kattintás és görgetéssel' is el lehessen érni.
- Lehetővé tettük a **Forgatást** a **Kattintás és görgetés** gesztussal.
- **Fejlesztettük** a **Trackpad Szimuláció** opció működését bizonyos helyzetekben. Például amikor vízszintesen görgetsz egy üzenet törléséhez a Mailben, az üzenet mozgásának iránya most meg van fordítva, ami remélem, természetesebbnek és következetesebbnek érződik a legtöbb ember számára.
- Hozzáadtunk egy funkciót a **Elsődleges kattintás** vagy **Másodlagos kattintás** **újratérképezéséhez**. Ezt azért valósítottam meg, mert a kedvenc egeremen eltört a jobb gomb. Ezek az opciók alapértelmezetten rejtettek. Az Option billentyű lenyomva tartásával láthatod őket egy művelet kiválasztásakor.
  - Ehhez jelenleg hiányoznak a kínai és koreai fordítások, így ha szeretnél hozzájárulni ezeknek a funkcióknak a fordításához, azt nagyra értékelnénk!

**Hibajavítások**

- Javítottuk azt a hibát, ahol a 'Mission Control és Terek' **'Kattintás és húzás'** **iránya fordított** volt azoknál a felhasználóknál, akik soha nem kapcsolták át a 'Természetes görgetés' opciót a Rendszerbeállításokban. Most a Mac Mouse Fix 'Kattintás és húzás' gesztusainak iránya mindig meg kell, hogy egyezzen a Trackpaden vagy Magic Mouse-on használt gesztusok irányával. Ha szeretnél egy külön opciót a 'Kattintás és húzás' irányának megfordítására ahelyett, hogy az a Rendszerbeállításokat követné, jelezd.
- Javítottuk azt a hibát, ahol a **próbaidő napjai túl gyorsan** számolódtak fel egyes felhasználóknál. Ha érintett voltál ebben, jelezd, és megnézem, mit tehetek.
- Javítottuk azt a problémát macOS Sonoma alatt, ahol a fülsáv nem jelent meg megfelelően.
- Javítottuk a döcögést a 'macOS' görgetési sebesség használatakor, amikor 'Kattintás és görgetéssel' nyitod meg a Launchpadet.
- Javítottuk azt a hibát, ahol a 'Mac Mouse Fix Helper' alkalmazás (amely a háttérben fut, amikor a Mac Mouse Fix engedélyezve van) néha összeomlott billentyűparancs rögzítésekor.
- Javítottuk azt a hibát, ahol a Mac Mouse Fix összeomlott, amikor megpróbálta felvenni a [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma) által generált mesterséges eseményeket.
- Javítottuk azt a problémát, ahol egyes egerek neve kétszer tartalmazta a gyártót az 'Alapértelmezések visszaállítása...' párbeszédablakban.
- Csökkentettük annak esélyét, hogy a 'Mission Control és Terek' 'Kattintás és húzás' funkció beragadjon, amikor a számítógép lassú.
- Javítottuk a 'Force Touch' használatát a felhasználói felület szövegeiben, ahol 'Force click'-nek kellene lennie.
- Javítottuk azt a hibát, amely bizonyos konfigurációknál fordult elő, ahol a Launchpad megnyitása vagy az Asztal megjelenítése 'Kattintás és görgetéssel' nem működött, ha felengedted a gombot, miközben az átmeneti animáció még tartott.


**Egyéb**

- Számos háttérbeli fejlesztés, stabilitási javítás, háttérkód tisztítás és egyéb.

## Hogyan segíthetsz

Segíthetsz az **ötleteid**, **problémáid** és **visszajelzéseid** megosztásával!

Az **ötletek** és **problémák** megosztásának legjobb helye a [Visszajelzési Asszisztens](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
A **gyors**, strukturálatlan visszajelzések legjobb helye a [Visszajelzési Beszélgetés](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Ezeket a helyeket az alkalmazáson belül is elérheted a '**ⓘ Névjegy**' fülön.

**Köszönjük**, hogy segítesz jobbá tenni a Mac Mouse Fix-et! 😎:)