A Mac Mouse Fix **3.0.5** több hibát javít, javítja a teljesítményt, és egy kis csiszolást ad az alkalmazásnak. \
Emellett kompatibilis a macOS 26 Tahoe-val is.

### Továbbfejlesztett trackpad görgetés szimuláció

- A görgetési rendszer most már képes szimulálni a kétujjas érintést a trackpadon, hogy az alkalmazások leállítsák a görgetést.
    - Ez javít egy problémát iPhone vagy iPad alkalmazások futtatásakor, ahol a görgetés gyakran folytatódott azután is, hogy a felhasználó le akarta állítani.
- Javítva lett az ujjak trackpadról való felemelésének következetlen szimulációja.
    - Ez bizonyos helyzetekben nem optimális viselkedést okozhatott.



### macOS 26 Tahoe kompatibilitás

A macOS 26 Tahoe Beta futtatásakor az alkalmazás most már használható, és a felhasználói felület nagy része megfelelően működik.



### Teljesítmény javítás

Javítva lett a kattintás és húzás "Görgetés és navigálás" gesztus teljesítménye. \
A tesztjeim során a CPU használat körülbelül 50%-kal csökkent!

**Háttér**

A "Görgetés és navigálás" gesztus során a Mac Mouse Fix egy hamis egérkurzort rajzol egy átlátszó ablakba, miközben a valódi egérkurzort a helyén rögzíti. Ez biztosítja, hogy továbbra is görgetheted azt a felhasználói felület elemet, amelyen elkezdted a görgetést, függetlenül attól, hogy milyen messzire mozgatod az egeredet.

A javított teljesítményt az érte el, hogy kikapcsoltuk az alapértelmezett macOS eseménykezelést ezen az átlátszó ablakon, amit amúgy sem használtunk.





### Hibajavítások

- Most már figyelmen kívül hagyjuk a Wacom rajztáblák görgetési eseményeit.
    - Korábban a Mac Mouse Fix szabálytalan görgetést okozott a Wacom táblákon, ahogy azt @frenchie1980 jelentette a GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233)-ban. (Köszönet!)
    
- Javítva lett egy hiba, ahol a Swift Concurrency kód, amely a Mac Mouse Fix 3.0.4 új licencelési rendszerének részeként került bevezetésre, nem a megfelelő szálon futott.
    - Ez összeomlásokat okozott macOS Tahoe-n, és valószínűleg más szórványos hibákat is okozott a licenceléssel kapcsolatban.
- Javítva lett az offline licencek dekódolását végző kód robusztussága.
    - Ez megkerül egy problémát az Apple API-jaiban, amely miatt az offline licenc validáció mindig sikertelen volt az Intel Mac Mini-men. Feltételezem, hogy ez minden Intel Mac-en előfordult, és ez volt az oka annak, hogy a "Free days are over" hiba (amelyet már a 3.0.4-ben kezeltek) még mindig előfordult néhány embernél, ahogy azt @toni20k5267 jelentette a GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356)-ban. (Köszönöm!)
        - Ha tapasztaltad a "Free days are over" hibát, sajnálom! Visszatérítést kérhetsz [itt](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Felhasználói élmény javítások

- Letiltva lettek azok a párbeszédablakok, amelyek lépésről lépésre megoldásokat kínáltak olyan macOS hibákra, amelyek megakadályozták a felhasználókat a Mac Mouse Fix engedélyezésében.
    - Ezek a problémák csak macOS 13 Ventura és 14 Sonoma rendszereken fordultak elő. Most ezek a párbeszédablakok csak azokon a macOS verziókon jelennek meg, ahol relevánsak.
    - A párbeszédablakok aktiválása is egy kicsit nehezebb lett – korábban néha olyan helyzetekben is megjelentek, ahol nem voltak túl hasznosak.
    
- Hozzáadtunk egy "Licenc aktiválása" linket közvetlenül a "Free days are over" értesítésre.
    - Ez még egyszerűbbé teszi a Mac Mouse Fix licenc aktiválását!

### Vizuális fejlesztések

- Kissé javítva lett a "Szoftverfrissítés" ablak kinézete. Most jobban illeszkedik a macOS 26 Tahoe-hoz.
    - Ez a "Sparkle 1.27.3" keretrendszer alapértelmezett kinézetének testreszabásával történt, amelyet a Mac Mouse Fix a frissítések kezelésére használ.
- Javítva lett a probléma, ahol a Névjegy fül alján lévő szöveg néha levágódott kínaiul, az ablak kissé szélesebbé tételével.
- Javítva lett, hogy a Névjegy fül alján lévő szöveg kissé el volt tolva a középtől.
- Javítva lett egy hiba, amely miatt a "Billentyűparancs..." opció alatti hely a Gombok fülön túl kicsi volt.

### Motorháztető alatti változások

- Eltávolítva lett a "SnapKit" keretrendszertől való függőség.
    - Ez kissé csökkenti az alkalmazás méretét 19,8 MB-ról 19,5 MB-ra.
- Különféle egyéb apró fejlesztések a kódbázisban.

*Szerkesztve Claude kiváló segítségével.*

---

Nézd meg az előző kiadást is: [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).