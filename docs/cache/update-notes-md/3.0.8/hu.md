A Mac Mouse Fix **3.0.8** felhasználói felület problémákat és egyebeket old meg.

### **Felhasználói felület problémák**

- Letiltottam az új dizájnt macOS 26 Tahoe alatt. Most az alkalmazás úgy fog kinézni és működni, mint macOS 15 Sequoia alatt.
    - Azért tettem ezt, mert az Apple néhány újratervezett felhasználói felület eleme még mindig problémás. Például a „Gombok" fül „-" gombjai nem mindig voltak kattinthatók.
    - A felhasználói felület most kissé elavultnak tűnhet macOS 26 Tahoe alatt. De teljesen működőképes és csiszolt lesz, mint korábban.
- Kijavítottam egy hibát, ahol az „Ingyenes napok véget értek" értesítés beragadt a képernyő jobb felső sarkában.
    - Köszönet [Sashpuri](https://github.com/Sashpuri)-nak és másoknak a bejelentésért!

### **Felhasználói felület finomítások**

- Letiltottam a zöld jelzőlámpa gombot a fő Mac Mouse Fix ablakban.
    - A gomb nem csinált semmit, mivel az ablak nem méretezhető át manuálisan.
- Kijavítottam egy problémát, ahol a „Gombok" fül táblázatában néhány vízszintes vonal túl sötét volt macOS 26 Tahoe alatt.
- Kijavítottam egy hibát, ahol az „Elsődleges egérgomb nem használható" üzenet a „Gombok" fülön néha levágásra került macOS 26 Tahoe alatt.
- Kijavítottam egy elírást a német felületen. A GitHub felhasználó [i-am-the-slime](https://github.com/i-am-the-slime) jóvoltából. Köszönet!
- Megoldottam egy problémát, ahol az MMF ablak néha röviden rossz méretben villant fel az ablak megnyitásakor macOS 26 Tahoe alatt.

### **Egyéb változások**

- Javítottam a viselkedést, amikor megpróbálod engedélyezni a Mac Mouse Fix-et, miközben több Mac Mouse Fix példány fut a számítógépen.
    - A Mac Mouse Fix most szorgalmasabban próbálja letiltani a Mac Mouse Fix másik példányát.
    - Ez javíthat olyan szélsőséges eseteket, ahol a Mac Mouse Fix nem volt engedélyezhető.
- Háttérben történő változások és tisztítás.

---

Nézd meg azt is, mi újság az előző [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7) verzióban.