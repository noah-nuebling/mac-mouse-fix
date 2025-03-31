A Mac Mouse Fix **3.0.1** számos hibajavítást és fejlesztést hoz, valamint egy **új nyelvet**!

### Vietnámi nyelv hozzáadva!

A Mac Mouse Fix már elérhető 🇻🇳 vietnámi nyelven is. Hatalmas köszönet @nghlt-nek a [GitHubon](https://GitHub.com/nghlt)!


### Hibajavítások

- A Mac Mouse Fix most már megfelelően működik a **Gyors felhasználóváltással**!
  - A Gyors felhasználóváltás az, amikor bejelentkezel egy második macOS fiókba anélkül, hogy kijelentkeznél az elsőből.
  - A frissítés előtt a görgetés nem működött felhasználóváltás után. Most már minden megfelelően működik.
- Javítva lett egy apró hiba, ahol a Gombok fül elrendezése túl széles volt a Mac Mouse Fix első indításakor.
- A '+' mező megbízhatóbban működik, amikor gyors egymásutánban több Műveletet adsz hozzá.
- Javítva lett egy ritka összeomlás, amit @V-Coba jelentett a [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735)-ös hibajegyben.

### Egyéb fejlesztések

- A **görgetés érzékenyebb** a 'Simaság: Normál' beállítás használatakor.
  - Az animáció sebessége most gyorsabb lesz, ahogy gyorsabban mozgatod a görgőt. Így érzékenyebben reagál gyors görgetéskor, miközben ugyanolyan sima marad lassú görgetésnél.

- A **görgetési sebesség gyorsulása** stabilabb és kiszámíthatóbb lett.
- Bevezetésre került egy mechanizmus a **beállításaid megőrzésére** új Mac Mouse Fix verzióra frissítéskor.
  - Korábban a Mac Mouse Fix alaphelyzetbe állította az összes beállítást új verzióra frissítéskor, ha a beállítások szerkezete megváltozott. Most a Mac Mouse Fix megpróbálja frissíteni a beállításaid szerkezetét és megőrizni a preferenciáidat.
  - Ez egyelőre csak a 3.0.0-ról 3.0.1-re frissítéskor működik. Ha 3.0.0-nál régebbi verzióról frissítesz, vagy ha _visszalépsz_ 3.0.1-ről egy korábbi verzióra, a beállításaid továbbra is alaphelyzetbe állnak.
- A Gombok fül elrendezése most jobban alkalmazkodik a különböző nyelvek szélességéhez.
- Fejlesztések a [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background)-ben és egyéb dokumentumokban.
- Fejlesztett lokalizációs rendszerek. A fordítási fájlok most automatikusan tisztulnak és elemzésre kerülnek a lehetséges problémák szempontjából. Létrejött egy új [Lokalizációs Útmutató](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731), amely tartalmazza az automatikusan észlelt problémákat és egyéb hasznos információkat, útmutatásokat azok számára, akik szeretnének segíteni a Mac Mouse Fix fordításában. Eltávolítottuk a függőséget a [BartyCrouch](https://github.com/FlineDev/BartyCrouch) eszköztől, amit korábban használtunk néhány ilyen funkció eléréséhez.
- Számos UI szöveg fejlesztése angol és német nyelven.
- Sok háttérbeli tisztítás és fejlesztés.

---

Nézd meg a [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) kiadási jegyzeteit is - a Mac Mouse Fix eddigi legnagyobb frissítését!