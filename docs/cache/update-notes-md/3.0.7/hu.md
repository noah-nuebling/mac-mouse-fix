A Mac Mouse Fix **3.0.7** több fontos hibát javít.

### Hibajavítások

- Az alkalmazás ismét működik **régebbi macOS verziókon** (macOS 10.15 Catalina és macOS 11 Big Sur) 
    - A Mac Mouse Fix 3.0.6 nem volt engedélyezhető ezeken a macOS verziókon, mert a Mac Mouse Fix 3.0.6-ban bevezetett továbbfejlesztett „Vissza" és „Előre" funkció olyan macOS rendszer API-kat próbált használni, amelyek nem voltak elérhetők.
- Javítva lettek a **„Vissza" és „Előre"** funkcióval kapcsolatos problémák
    - A Mac Mouse Fix 3.0.6-ban bevezetett továbbfejlesztett „Vissza" és „Előre" funkció mostantól mindig a „fő szálat" fogja használni, hogy megkérdezze a macOS-t arról, mely billentyűleütéseket szimulálja a vissza és előre lépéshez az éppen használt alkalmazásban. \
    Ez megakadályozhatja az összeomlásokat és a megbízhatatlan viselkedést bizonyos helyzetekben.
- Kísérlet a **beállítások véletlenszerű visszaállítása** hibájának javítására  (Lásd ezeket a [GitHub Issue-kat](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Újraírtam a Mac Mouse Fix konfigurációs fájlját betöltő kódot, hogy robusztusabb legyen. Amikor ritka macOS fájlrendszer-hibák léptek fel, a régi kód néha tévesen azt gondolhatta, hogy a konfigurációs fájl sérült, és visszaállította az alapértelmezettre.
- Csökkentve a **görgetés leállása** hibájának esélye     
     - Ez a hiba nem oldható meg teljesen mélyebb változtatások nélkül, amelyek valószínűleg más problémákat okoznának. \
      Azonban egyelőre csökkentettem azt az időablakot, amikor „holtpont" alakulhat ki a görgetési rendszerben, aminek legalább csökkentenie kellene a hiba előfordulásának esélyét. Ez a görgetést is valamivel hatékonyabbá teszi. 
    - Ennek a hibának hasonló tünetei vannak – de szerintem más az alapvető oka –, mint a „Görgetés időszakosan leáll" hibának, amelyet az előző 3.0.6-os kiadásban javítottunk.
    - (Köszönet Joonasnak a diagnosztikáért!) 

Köszönet mindenkinek a hibajelentésekért! 

---

Nézd meg az előző kiadást is: [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).