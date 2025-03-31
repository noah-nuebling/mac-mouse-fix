De asemenea, verifică **îmbunătățirile interesante** introduse în [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6)!


---

**3.0.0 Beta 7** aduce câteva îmbunătățiri minore și remedieri de erori.

Iată toate noutățile:

**Îmbunătățiri**

- Au fost adăugate **traduceri în coreeană**. Mulțumiri mari lui @jeongtae! (Îl poți găsi pe [GitHub](https://github.com/jeongtae))
- Am făcut **derularea** cu opțiunea 'Fluiditate: Ridicată' **și mai fluidă**, schimbând viteza doar treptat, în loc să existe salturi bruște în viteza de derulare când miști rotița. Acest lucru ar trebui să facă derularea puțin mai fluidă și mai ușor de urmărit cu ochii fără a face lucrurile mai puțin responsive. Derularea cu 'Fluiditate: Ridicată' folosește acum cu aproximativ 30% mai mult CPU, pe computerul meu a crescut de la 1.2% utilizare CPU la derulare continuă la 1.6%. Deci derularea rămâne foarte eficientă și sper că această diferență nu va afecta pe nimeni. Mulțumiri mari [MOS](https://mos.caldis.me/), care a inspirat această funcție și al cărui 'Scroll Monitor' l-am folosit pentru implementare.
- Mac Mouse Fix acum **gestionează comenzile de la toate sursele**. Înainte, Mac Mouse Fix gestiona doar comenzile de la mouse-urile pe care le recunoștea. Cred că acest lucru ar putea ajuta compatibilitatea cu anumite mouse-uri în cazuri particulare, cum ar fi când folosești un Hackintosh, dar va face și ca Mac Mouse Fix să preia comenzi generate artificial de alte aplicații, ceea ce ar putea duce la probleme în alte cazuri particulare. Anunță-mă dacă acest lucru îți creează probleme și le voi rezolva în actualizări viitoare.
- Am rafinat senzația și finisajul gesturilor 'Click și Derulare' pentru 'Desktop & Launchpad' și 'Click și Derulare' pentru 'Deplasare între Spații'.
- Acum luăm în considerare densitatea informațională a unei limbi când calculăm **timpul de afișare al notificărilor**. Înainte, notificările rămâneau vizibile pentru o perioadă foarte scurtă în limbile cu densitate informațională ridicată precum chineza sau coreeana.
- Am activat **gesturi diferite** pentru deplasarea între **Spații**, deschiderea **Mission Control** sau deschiderea **App Exposé**. În Beta 6, am făcut ca aceste acțiuni să fie disponibile doar prin gestul 'Click și Tragere' - ca un experiment pentru a vedea câți oameni chiar țin să poată accesa aceste acțiuni în alte moduri. Se pare că unii țin, așa că acum am făcut din nou posibil să accesezi aceste acțiuni printr-un simplu 'Click' al unui buton sau prin 'Click și Derulare'.
- Am făcut posibilă **Rotirea** printr-un gest de **Click și Derulare**.
- Am **îmbunătățit** modul în care funcționează opțiunea de **Simulare Trackpad** în anumite scenarii. De exemplu, când derulezi orizontal pentru a șterge un mesaj în Mail, direcția în care se mișcă mesajul este acum inversată, ceea ce sper că se simte mai natural și consistent pentru majoritatea oamenilor.
- Am adăugat o funcție pentru **remapare** la **Click Primar** sau **Click Secundar**. Am implementat acest lucru pentru că butonul drept al mouse-ului meu preferat s-a stricat. Aceste opțiuni sunt ascunse implicit. Le poți vedea ținând apăsată tasta Option în timp ce selectezi o acțiune.
  - Momentan lipsesc traducerile pentru chineză și coreeană, așa că dacă dorești să contribui cu traduceri pentru aceste funcții, ar fi foarte apreciat!

**Remedieri de Erori**

- Am remediat o eroare unde **direcția 'Click și Tragere'** pentru 'Mission Control & Spații' era **inversată** pentru persoanele care nu au schimbat niciodată opțiunea 'Derulare naturală' în Setări Sistem. Acum, direcția gesturilor 'Click și Tragere' în Mac Mouse Fix ar trebui să se potrivească întotdeauna cu direcția gesturilor de pe Trackpad sau Magic Mouse. Dacă dorești o opțiune separată pentru inversarea direcției 'Click și Tragere', în loc să urmeze Setările Sistem, anunță-mă.
- Am remediat o eroare unde **zilele gratuite** se **numărau prea repede** pentru unii utilizatori. Dacă ai fost afectat de acest lucru, anunță-mă și voi vedea ce pot face.
- Am remediat o problemă în macOS Sonoma unde bara de file nu se afișa corect.
- Am remediat sacadarea când folosești viteza de derulare 'macOS' în timp ce folosești 'Click și Derulare' pentru a deschide Launchpad.
- Am remediat o eroare unde aplicația 'Mac Mouse Fix Helper' (care rulează în fundal când Mac Mouse Fix este activat) se bloca uneori la înregistrarea unei comenzi rapide de la tastatură.
- Am remediat o eroare unde Mac Mouse Fix se bloca când încerca să preia evenimente artificiale generate de [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma)
- Am remediat o problemă unde numele unor mouse-uri afișate în dialogul 'Restaurare Valori Implicite...' conținea producătorul de două ori.
- Am făcut mai puțin probabil ca 'Click și Tragere' pentru 'Mission Control & Spații' să se blocheze când computerul este lent.
- Am corectat utilizarea 'Force Touch' în textele interfeței unde ar fi trebuit să fie 'Force click'.
- Am remediat o eroare care apărea pentru anumite configurații, unde deschiderea Launchpad sau afișarea Desktop-ului prin 'Click și Derulare' nu funcționa dacă eliberai butonul în timp ce animația de tranziție era încă în desfășurare.


**Mai Multe**

- Mai multe îmbunătățiri sub capotă, îmbunătățiri de stabilitate, curățare sub capotă și altele.

## Cum Poți Ajuta

Poți ajuta împărtășind **ideile**, **problemele** și **feedback-ul** tău!

Cel mai bun loc pentru a împărtăși **ideile** și **problemele** tale este [Asistentul de Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Cel mai bun loc pentru a oferi feedback **rapid** nestructurat este [Discuția de Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Poți accesa aceste locuri și din aplicație în fila '**ⓘ Despre**'.

**Mulțumesc** că ajuți la îmbunătățirea Mac Mouse Fix! 😎:)