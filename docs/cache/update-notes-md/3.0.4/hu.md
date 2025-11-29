A Mac Mouse Fix **3.0.4** javítja az adatvédelmet, a hatékonyságot és a megbízhatóságot.\
Új offline licencrendszert vezet be, és több fontos hibát javít.

### Továbbfejlesztett adatvédelem és hatékonyság

A 3.0.4 új offline licencvalidációs rendszert vezet be, amely a lehető legkevesebb internetkapcsolatot használja.\
Ez javítja az adatvédelmet és kíméli a számítógéped rendszererőforrásait.\
Licencelt állapotban az alkalmazás most már 100%-ban offline működik!

<details>
<summary><b>Kattints ide a részletekért</b></summary>
A korábbi verziók minden indításkor online validálták a licenceket, ami lehetővé tette, hogy harmadik féltől származó szerverek (GitHub és Gumroad) kapcsolódási naplókat tároljanak. Az új rendszer megszünteti a felesleges kapcsolatokat – a kezdeti licencaktiválás után csak akkor csatlakozik az internethez, ha a helyi licencadatok sérültek.
<br><br>
Bár személyesen soha nem rögzítettem felhasználói viselkedést, a korábbi rendszer elméletileg lehetővé tette harmadik féltől származó szerverek számára, hogy naplózzák az IP-címeket és a kapcsolódási időpontokat. A Gumroad szintén naplózhatta a licenckulcsodat, és potenciálisan összekapcsolhatta azt bármilyen személyes adattal, amit rólad rögzítettek a Mac Mouse Fix vásárlásakor.
<br><br>
Nem vettem figyelembe ezeket a finom adatvédelmi kérdéseket, amikor az eredeti licencrendszert építettem, de most a Mac Mouse Fix olyan privát és internetmentes, amennyire csak lehetséges!
<br><br>
Lásd még a <a href=https://gumroad.com/privacy>Gumroad adatvédelmi szabályzatát</a> és ezt a <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub hozzászólásomat</a>.

</details>

### Hibajavítások

- Javítva lett egy hiba, amely miatt a macOS néha lefagyott, amikor a 'Kattintás és húzás' funkciót használtad a 'Spaces és Mission Control' esetében.
- Javítva lett egy hiba, amely miatt a Rendszerbeállításokban lévő billentyűparancsok néha törlődtek, amikor Mac Mouse Fix 'Kattintás' műveleteket használtál, mint például a 'Mission Control'.
- Javítva lett [egy hiba](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22), amely miatt az alkalmazás néha leállt és egy értesítést jelenített meg, hogy 'Az ingyenes napok véget értek' olyan felhasználóknak, akik már megvásárolták az alkalmazást.
    - Ha te is tapasztaltad ezt a hibát, őszintén elnézést kérek az okozott kellemetlenségért. [Itt kérhetsz visszatérítést](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Javítottuk azt a módot, ahogyan az alkalmazás lekéri a főablakát, ami esetleg javított egy hibát, amikor a 'Licenc aktiválása' képernyő néha nem jelent meg.

### Használhatósági fejlesztések

- Lehetetlenné tettük szóközök és sortörések beírását a 'Licenc aktiválása' képernyő szövegmezőjébe.
    - Ez gyakori zavart okozott, mert nagyon könnyű véletlenül kijelölni egy rejtett sortörést, amikor a licenckulcsodat másolod a Gumroad e-mailjeiből.
- Ezek a frissítési megjegyzések automatikusan le vannak fordítva a nem angol nyelvű felhasználók számára (Claude által működtetve). Remélem, hasznos! Ha bármilyen problémát tapasztalsz vele, jelezd nekem. Ez egy első pillantás egy új fordítási rendszerre, amelyen az elmúlt évben dolgoztam.

### A macOS 10.14 Mojave (nem hivatalos) támogatásának megszüntetése

A Mac Mouse Fix 3 hivatalosan a macOS 11 Big Sur és újabb verziókat támogatja. Azonban azok számára, akik hajlandóak elfogadni néhány hibát és grafikai problémát, a Mac Mouse Fix 3.0.3 és korábbi verziók még használhatók voltak macOS 10.14.4 Mojave alatt.

A Mac Mouse Fix 3.0.4 megszünteti ezt a támogatást, és **most már macOS 10.15 Catalina szükséges hozzá**. \
Elnézést kérek minden ebből eredő kellemetlenségért. Ez a változtatás lehetővé tette számomra, hogy a továbbfejlesztett licencrendszert modern Swift funkciókkal implementáljam. A Mojave felhasználók továbbra is használhatják a Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) verziót vagy a [Mac Mouse Fix 2 legújabb verzióját](https://redirect.macmousefix.com/?target=mmf2-latest). Remélem, ez mindenkinek megfelelő megoldás.

### Háttérben történt fejlesztések

- Új 'MFDataClass' rendszer implementálása, amely erőteljesebb adatmodellezést tesz lehetővé, miközben a Mac Mouse Fix konfigurációs fájlja ember által olvasható és szerkeszthető marad.
- Támogatás kiépítése a Gumroadon kívüli fizetési platformok hozzáadásához. Így a jövőben lehetnek lokalizált fizetési folyamatok, és az alkalmazás különböző országokban értékesíthető.
- Továbbfejlesztett naplózás, amely lehetővé teszi számomra hatékonyabb "Debug Build"-ek létrehozását olyan felhasználók számára, akik nehezen reprodukálható hibákat tapasztalnak.
- Sok más apró fejlesztés és tisztítási munka.

*Szerkesztve a Claude kiváló segítségével.*

---

Nézd meg az előző kiadást is: [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).