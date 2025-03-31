Mac Mouse Fix **3.0.2** aduce mai multe îmbunătățiri, inclusiv **derulare mai fluidă**, traduceri îmbunătățite și multe altele!

### Derulare

- Acum poți opri animațiile de derulare prin derularea unui pas în direcția opusă. Acest lucru îți permite să **"arunci"** și să **"prinzi pagina"** când folosești 'Fluiditate: Ridicată', similar cu un Trackpad.
- Mac Mouse Fix trimite acum evenimente de derulare mai devreme în ciclul de reîmprospătare a afișajului, oferind aplicațiilor mai mult timp pentru a procesa evenimentele de derulare și a afișa derularea fluid. Acest lucru **îmbunătățește rata cadrelor**, în special pe site-uri complexe precum YouTube.com.
- Am îmbunătățit reactivitatea setării 'Fluiditate: Ridicată', făcând derularea mai ușor de controlat.
- Am îmbunătățit un mecanism introdus în 3.0.1 unde viteza animației devine mai rapidă pe măsură ce rotești rotița mai repede când folosești 'Fluiditate: Normală'. În 3.0.2, accelerarea animației ar trebui să apară mai consistentă și previzibilă, făcând-o mai plăcută pentru ochi în timp ce oferă un control excelent.
- Am rezolvat o problemă unde viteza de derulare era prea lentă, în special când se folosea opțiunea 'Precizie'. Această problemă a fost introdusă în 3.0.1. Mulțumim lui @V-Coba pentru că a atras atenția asupra acesteia în [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- Am îmbunătățit comportamentul în browserul Arc când se folosește 'Click și Derulare' pentru 'Mărire sau Micșorare'.

### Localizare

- Am actualizat traducerile în 🇻🇳 Vietnameză. Mulțumiri lui @nghlt!
- Am îmbunătățit unele traduceri în 🇩🇪 Germană.
- Textul din Mac Mouse Fix care nu are o traducere pentru limba curentă va afișa acum o valoare temporară în loc să rămână gol. Acest lucru ar trebui să facă navigarea în aplicație mai puțin confuză când lipsesc traduceri.

### Altele

- Mac Mouse Fix va afișa acum o notificare cu un link către [acest ghid](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) utilizatorilor care ar putea întâmpina un bug în macOS 13 Ventura și versiunile ulterioare care poate împiedica activarea Mac Mouse Fix.
- Am modificat setările implicite pentru mouse-urile cu 3 butoane. Setările implicite nu mai includ o acțiune 'Click și Derulare' pentru Butonul Rotiță, deoarece este destul de greu de executat. În schimb, setările implicite includ acum o acțiune 'Menținere' și 'Dublu Click'.
- Am adăugat un tooltip la iconița Mac Mouse Fix din tab-ul Despre. Acesta îți spune cum să găsești fișierul de configurare Mac Mouse Fix în Finder.
- Multe îmbunătățiri și curățări la nivel intern.

---

De asemenea, verifică versiunea anterioară [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).