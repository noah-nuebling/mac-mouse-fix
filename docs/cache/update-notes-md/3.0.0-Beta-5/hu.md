Nézd meg a **remek változtatásokat** is a [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4) verzióban!

---

A **3.0.0 Beta 5** visszaállítja a **kompatibilitást** néhány **egérrel** macOS 13 Ventura alatt, és **javítja a görgetést** számos alkalmazásban.
Emellett több kisebb javítást és életminőség-javító fejlesztést is tartalmaz.

Itt van **minden újdonság**:

### Egér

- Javítva a görgetés a Terminalban és más alkalmazásokban! Lásd a GitHub Issue [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413)-at.
- Javítva a kompatibilitási probléma néhány egérrel macOS 13 Ventura alatt azáltal, hogy a megbízhatatlan Apple API-k helyett alacsony szintű megoldásokat használunk. Reméljük, ez nem okoz új problémákat - jelezd, ha mégis! Külön köszönet Mariának és [samiulhsnt](https://github.com/samiulhsnt) GitHub felhasználónak a segítségért! További információkért lásd a GitHub Issue [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424)-et.
- Már nem használ CPU-t az 1-es vagy 2-es egérgomb kattintásakor. Enyhén csökkentett CPU-használat más gombok kattintásakor.
    - Ez egy "Debug Build", így a CPU-használat körülbelül 10-szer magasabb lehet a gombok kattintásakor ebben a bétában a végleges kiadáshoz képest
- A trackpad görgetés szimuláció, amit a Mac Mouse Fix "Smooth Scrolling" és "Scroll & Navigate" funkcióihoz használunk, most még pontosabb. Ez néhány helyzetben jobb működést eredményezhet.

### Felhasználói felület

- Automatikusan javítja az Accessibility hozzáférés engedélyezésével kapcsolatos problémákat a Mac Mouse Fix régebbi verziójáról történő frissítés után. Átveszi a [2.2.2 kiadási jegyzetekben](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2) leírt változtatásokat.
- "Mégse" gomb hozzáadva az "Accessibility hozzáférés engedélyezése" képernyőhöz
- Javítva egy probléma, ahol a Mac Mouse Fix konfigurálása nem működött megfelelően új verzió telepítése után, mert az új verzió a "Mac Mouse Fix Helper" régi verziójához csatlakozott. Most a Mac Mouse Fix már nem csatlakozik a régi "Mac Mouse Fix Helper"-hez, és szükség esetén automatikusan letiltja a régi verziót.
- Útmutatást ad a felhasználónak olyan probléma megoldásához, amikor a Mac Mouse Fix nem engedélyezhető megfelelően egy másik Mac Mouse Fix verzió jelenléte miatt a rendszeren. Ez a probléma csak macOS Ventura alatt fordul elő.
- Finomított viselkedés és animációk az "Accessibility hozzáférés engedélyezése" képernyőn
- A Mac Mouse Fix előtérbe kerül, amikor engedélyezve van. Ez javítja a felhasználói felület interakcióit bizonyos helyzetekben, például amikor a Mac Mouse Fix-et a Rendszerbeállítások > Általános > Bejelentkezési elemek alatt történt letiltás után engedélyezed.
- Javított UI szövegek az "Accessibility hozzáférés engedélyezése" képernyőn
- Javított UI szövegek, amelyek akkor jelennek meg, amikor a Mac Mouse Fix-et próbálod engedélyezni, miközben le van tiltva a Rendszerbeállításokban
- Javított német UI szöveg

### Háttérben

- A "Mac Mouse Fix" és a beágyazott "Mac Mouse Fix Helper" build száma most szinkronizálva van. Ez megakadályozza, hogy a "Mac Mouse Fix" véletlenül a "Mac Mouse Fix Helper" régi verzióihoz csatlakozzon.
- Javítva egy probléma, ahol a licenccel és próbaidőszakkal kapcsolatos adatok néha helytelenül jelentek meg az alkalmazás első indításakor, a kezdeti konfigurációból származó gyorsítótár-adatok eltávolításával
- Sok tisztogatás a projekt szerkezetében és forráskódjában
- Javított hibakeresési üzenetek

---

### Hogyan segíthetsz

Segíthetsz az **ötletek**, **problémák** és **visszajelzések** megosztásával!

Az **ötletek** és **problémák** megosztásának legjobb helye a [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
A **gyors**, strukturálatlan visszajelzések legjobb helye a [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Ezeket a helyeket az alkalmazáson belül is elérheted az "**ⓘ Névjegy**" fülön.

**Köszönjük**, hogy segítesz jobbá tenni a Mac Mouse Fix-et! 💙💛❤️