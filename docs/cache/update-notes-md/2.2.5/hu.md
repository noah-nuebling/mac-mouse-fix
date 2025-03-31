A Mac Mouse Fix **2.2.5** fejlesztéseket tartalmaz a frissítési mechanizmusban, és készen áll a macOS 15 Sequoia-ra!

### Új Sparkle frissítési keretrendszer

A Mac Mouse Fix a [Sparkle](https://sparkle-project.org/) frissítési keretrendszert használja a kiváló frissítési élmény biztosításához.

A 2.2.5-ös verzióval a Mac Mouse Fix a Sparkle 1.26.0-ról a legújabb [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3) verzióra vált, amely biztonsági javításokat, lokalizációs fejlesztéseket és egyéb újdonságokat tartalmaz.

### Okosabb frissítési mechanizmus

Új mechanizmus dönti el, hogy mely frissítést jelenítse meg a felhasználónak. A viselkedés a következőképpen változott:

1. Miután kihagysz egy **fő** frissítést (például 2.2.5 -> 3.0.0), továbbra is értesítést kapsz az új **kisebb** frissítésekről (például 2.2.5 -> 2.2.6).
    - Ez lehetővé teszi, hogy egyszerűen maradj a Mac Mouse Fix 2-nél, miközben továbbra is megkapod a frissítéseket, ahogy azt a GitHub [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962) számú problémában is megvitattuk.
2. A legújabb kiadás helyett a Mac Mouse Fix mostantól a legújabb fő verzió első kiadására való frissítést fogja mutatni.
    - Példa: Ha az MMF 2.2.5-öt használod, és az MMF 3.4.5 a legújabb verzió, az alkalmazás most az MMF 3 első verzióját (3.0.0) fogja mutatni a legújabb verzió (3.4.5) helyett. Így minden MMF 2.2.5 felhasználó láthatja az MMF 3.0.0 változáslistáját, mielőtt átvált az MMF 3-ra.
    - Megbeszélés:
        - Ennek fő oka, hogy korábban az év során sok MMF 2 felhasználó közvetlenül az MMF 2-ről az MMF 3.0.1-re vagy 3.0.2-re frissített. Mivel soha nem látták a 3.0.0 változáslistáját, lemaradtak az MMF 2 és MMF 3 közötti árazási változásokról (az MMF 3 már nem 100%-ban ingyenes). Így amikor az MMF 3 hirtelen azt mondta, hogy fizetniük kell az alkalmazás további használatáért, néhányan - érthetően - kissé összezavarodtak és felháborodtak.
        - Hátrány: Ha csak a legújabb verzióra szeretnél frissíteni, most néhány esetben kétszer kell frissítened. Ez kissé nem hatékony, de még mindig csak néhány másodpercet vesz igénybe. És mivel ez sokkal átláthatóbbá teszi a fő verziók közötti változásokat, szerintem ez észszerű kompromisszum.

### macOS 15 Sequoia támogatás

A Mac Mouse Fix 2.2.5 remekül fog működni az új macOS 15 Sequoia-n - ahogy a 2.2.4 is tette.

---

Nézd meg az előző [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) kiadást is.

*Ha problémád van a Mac Mouse Fix engedélyezésével a frissítés után, kérlek, nézd meg a ['Mac Mouse Fix engedélyezése' útmutatót](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*