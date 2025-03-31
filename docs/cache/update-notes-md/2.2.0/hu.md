Nézd meg a [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)-ben bevezetett **menő újdonságokat** is!

---

A Mac Mouse Fix **2.2.0** különféle használhatósági fejlesztéseket és hibajavításokat tartalmaz!

### Az Apple-exkluzív funkcióbillentyűkre való átrendelés most jobb

Az előző, 2.1.0-s frissítés egy új, menő funkciót vezetett be, amely lehetővé teszi az egérgombok átrendelését bármely billentyűzeten található gombra - még az Apple billentyűzeteken található speciális funkcióbillentyűkre is. A 2.2.0 további fejlesztéseket és finomításokat tartalmaz ehhez a funkcióhoz:

- Most már tarthatod az Option (⌥) billentyűt az Apple billentyűzeteken található speciális gombok átrendeléséhez - még akkor is, ha nincs Apple billentyűzeted.
- A funkcióbillentyű szimbólumok megjelenése javult, így jobban illeszkednek a többi szöveghez.
- A Caps Lock-ra való átrendelés lehetősége ki lett kapcsolva. Nem működött megfelelően.

### Műveletek könnyebb hozzáadása / eltávolítása

Néhány felhasználónak gondot okozott rájönni, hogy lehet Műveleteket hozzáadni és eltávolítani a Műveletek Táblázatból. A könnyebb érthetőség érdekében a 2.2.0 a következő változtatásokat és új funkciókat tartalmazza:

- Most már törölhetsz Műveleteket jobb kattintással.
  - Ez megkönnyíti a Műveletek törlési lehetőségének felfedezését.
  - A jobb kattintásos menü tartalmazza a '-' gomb szimbólumát. Ez segít felhívni a figyelmet a '-' _gombra_, ami aztán a '+' gombra irányítja a figyelmet. Ez remélhetőleg a Műveletek **hozzáadásának** lehetőségét is könnyebben felfedezhetővé teszi.
- Most már hozzáadhatsz Műveleteket a Műveletek Táblázathoz egy üres sorra való jobb kattintással.
- A '-' gomb most csak akkor aktív, amikor egy Művelet ki van választva. Ez érthetőbbé teszi, hogy a '-' gomb törli a kiválasztott Műveletet.
- Az alapértelmezett ablakmagasság meg lett növelve, így látható egy üres sor, amire jobb kattintással lehet Műveletet hozzáadni.
- A '+' és '-' gombok most már rendelkeznek eszköztippekkel.

### Kattintás és Húzás fejlesztések

A Kattintás és Húzás aktiválási küszöbértéke 5 pixelről 7 pixelre lett növelve. Ez megnehezíti a Kattintás és Húzás véletlen aktiválását, miközben továbbra is lehetővé teszi a felhasználók számára a Spaces-ek közötti váltást stb. kis, kényelmes mozdulatokkal.

### Egyéb UI változtatások

- A Műveletek Táblázat megjelenése fejlesztve lett.
- Különféle egyéb UI fejlesztések.

### Hibajavítások

- Javítva lett egy probléma, ahol a felhasználói felület nem volt kiszürkítve, amikor az MMF letiltott állapotban indult.
- Eltávolítva lett a rejtett "3-as Gomb Kattintás és Húzás" opció.
  - Kiválasztásakor az alkalmazás összeomlott. Ezt az opciót azért építettem be, hogy a Mac Mouse Fix jobban kompatibilis legyen a Blenderrel. De jelenlegi formájában nem túl hasznos a Blender felhasználók számára, mert nem lehet billentyűzet módosítókkal kombinálni. Tervezem a Blender kompatibilitás javítását egy jövőbeli kiadásban.