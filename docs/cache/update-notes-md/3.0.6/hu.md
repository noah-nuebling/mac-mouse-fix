A Mac Mouse Fix **3.0.6** kompatibilissé teszi a 'Vissza' és 'Előre' funkciót több alkalmazással.
Emellett számos hibát és problémát is kijavít.

### Továbbfejlesztett 'Vissza' és 'Előre' funkció

A 'Vissza' és 'Előre' egérgomb-hozzárendelések mostantól **több alkalmazásban működnek**, beleértve:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed és más kódszerkesztők
- Számos beépített Apple alkalmazás, mint a Előnézet, Jegyzetek, Rendszerbeállítások, App Store és Zene
- Adobe Acrobat
- Zotero
- És még sok más!

A megvalósítást a [LinearMouse](https://github.com/linearmouse/linearmouse) kiváló 'Universal Back and Forward' funkciója ihlette. Minden olyan alkalmazást támogatnia kell, amelyet a LinearMouse is támogat. \
Ráadásul olyan alkalmazásokat is támogat, amelyek általában billentyűparancsokat igényelnek a vissza és előre lépéshez, mint például a Rendszerbeállítások, App Store, Apple Jegyzetek és Adobe Acrobat. A Mac Mouse Fix mostantól felismeri ezeket az alkalmazásokat és szimulálja a megfelelő billentyűparancsokat.

Minden alkalmazás, amelyet valaha [GitHub Issue-ban kértek](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22), mostantól támogatott! (Köszönöm a visszajelzéseket!) \
Ha találsz olyan alkalmazást, amely még nem működik, jelezd egy [funkciókérésben](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### A 'Görgetés időnként leáll' hiba kezelése

Néhány felhasználó olyan [problémát](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) tapasztalt, amikor a **sima görgetés véletlenszerűen leáll**.

Bár soha nem tudtam reprodukálni a problémát, implementáltam egy lehetséges javítást:

Az alkalmazás mostantól többször próbálkozik, amikor a kijelző-szinkronizáció beállítása sikertelen. \
Ha az újrapróbálkozások után sem működik, az alkalmazás:

- Újraindítja a 'Mac Mouse Fix Helper' háttérfolyamatot, ami megoldhatja a problémát
- Létrehoz egy hibajelentést, amely segíthet a hiba diagnosztizálásában

Remélem, a probléma mostantól megoldódott! Ha mégsem, jelezd egy [hibajelentésben](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) vagy [e-mailben](http://redirect.macmousefix.com/?target=mailto-noah).



### Továbbfejlesztett szabadon forgó görgő viselkedés

A Mac Mouse Fix **többé nem gyorsítja fel a görgetést**, amikor szabadon pörgeted a görgőt az MX Master egéren. (Vagy bármely más szabadon forgó görgővel rendelkező egéren.)

Bár ez a 'görgetésgyorsítás' funkció hasznos a hagyományos görgőkön, egy szabadon forgó görgőn nehezebben irányíthatóvá teheti a dolgokat.

**Megjegyzés:** A Mac Mouse Fix jelenleg nem teljesen kompatibilis a legtöbb Logitech egérrel, beleértve az MX Mastert is. Tervezem a teljes támogatás hozzáadását, de valószínűleg eltart egy ideig. Addig is a legjobb harmadik féltől származó driver Logitech támogatással, amit ismerek, a [SteerMouse](https://plentycom.jp/en/steermouse/).





### Hibajavítások

- Kijavítottam egy hibát, amikor a Mac Mouse Fix néha újra engedélyezte a Rendszerbeállításokban korábban letiltott billentyűparancsokat  
- Kijavítottam egy összeomlást a 'Licenc aktiválása' gombra kattintáskor 
- Kijavítottam egy összeomlást, amikor a 'Mégse' gombra kattintottál közvetlenül a 'Licenc aktiválása' gomb megnyomása után (Köszönöm a jelentést, Ali!)
- Kijavítottam az összeomlásokat, amikor megpróbáltad használni a Mac Mouse Fixet, miközben nincs kijelző csatlakoztatva a Macedhez 
- Kijavítottam egy memóriaszivárgást és néhány más háttérproblémát az alkalmazásban való lapok közötti váltáskor 

### Vizuális fejlesztések

- Kijavítottam egy hibát, amikor a Névjegy lap néha túl magas volt, ami a [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)-ben jelent meg
- A 'Vége az ingyenes napoknak' értesítés szövege többé nem vágódik le kínaiul
- Kijavítottam egy vizuális hibát a '+' mező árnyékán bemenet rögzítése után
- Kijavítottam egy ritka hibát, amikor a helyőrző szöveg a 'Licenckulcs megadása' képernyőn középen kívül jelent meg
- Kijavítottam egy hibát, amikor néhány, az alkalmazásban megjelenített szimbólum rossz színű volt a sötét/világos mód közötti váltás után

### Egyéb fejlesztések

- Néhány animációt, mint például a lapváltás animációt, kissé hatékonyabbá tettem  
- Letiltottam a Touch Bar szövegkiegészítést a 'Licenckulcs megadása' képernyőn 
- Különféle kisebb háttérfejlesztések

*Szerkesztve Claude kiváló segítségével.*

---

Nézd meg az előző kiadást is: [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).