Verifică și **modificările interesante** introduse în [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

**3.0.0 Beta 5** restabilește **compatibilitatea** cu unele **mouse-uri** în macOS 13 Ventura și **repară derularea** în multe aplicații.
De asemenea, include mai multe remedieri minore și îmbunătățiri ale calității vieții.

Iată **toate noutățile**:

### Mouse

- Am reparat derularea în Terminal și alte aplicații! Vezi problema GitHub [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Am rezolvat incompatibilitatea cu unele mouse-uri în macOS 13 Ventura renunțând la utilizarea API-urilor Apple nesigure în favoarea unor hack-uri de nivel inferior. Sper că acest lucru nu va introduce probleme noi - anunță-mă dacă se întâmplă! Mulțumiri speciale Mariei și utilizatorului GitHub [samiulhsnt](https://github.com/samiulhsnt) pentru ajutorul în rezolvarea acestei probleme! Vezi problema GitHub [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) pentru mai multe informații.
- Nu va mai folosi CPU când se face click pe Butonul 1 sau 2 al mouse-ului. Am redus ușor utilizarea CPU-ului la click-urile pe alte butoane.
    - Aceasta este o "Versiune de Debug" așa că utilizarea CPU-ului poate fi de aproximativ 10 ori mai mare la click-urile pe butoane în această versiune beta față de versiunea finală
- Simularea derulării trackpad-ului folosită pentru funcțiile "Derulare Lină" și "Derulare & Navigare" ale Mac Mouse Fix este acum și mai precisă. Acest lucru ar putea duce la un comportament mai bun în anumite situații.

### Interfață

- Repararea automată a problemelor cu acordarea Accesului de Accesibilitate după actualizarea de la o versiune mai veche de Mac Mouse Fix. Adoptă modificările descrise în [Notele de lansare 2.2.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Am adăugat un buton "Anulare" în ecranul "Acordă Acces de Accesibilitate"
- Am reparat o problemă unde configurarea Mac Mouse Fix nu funcționa corect după instalarea unei noi versiuni de Mac Mouse Fix, deoarece noua versiune se conecta la versiunea veche de "Mac Mouse Fix Helper". Acum, Mac Mouse Fix nu se va mai conecta la vechiul "Mac Mouse Fix Helper" și va dezactiva automat versiunea veche când este necesar.
- Oferirea instrucțiunilor utilizatorului despre cum să repare o problemă unde Mac Mouse Fix nu poate fi activat corect din cauza prezenței unei alte versiuni de Mac Mouse Fix în sistem. Această problemă apare doar în macOS Ventura.
- Am îmbunătățit comportamentul și animațiile în ecranul "Acordă Acces de Accesibilitate"
- Mac Mouse Fix va fi adus în prim-plan când este activat. Acest lucru îmbunătățește interacțiunile cu interfața în anumite situații, cum ar fi când activezi Mac Mouse Fix după ce a fost dezactivat în Setări Sistem > General > Elemente de Login.
- Am îmbunătățit textele din interfață în ecranul "Acordă Acces de Accesibilitate"
- Am îmbunătățit textele din interfață care apar când încerci să activezi Mac Mouse Fix în timp ce este dezactivat în Setări Sistem
- Am reparat un text în limba germană din interfață

### Sub capotă

- Numărul de build al "Mac Mouse Fix" și al "Mac Mouse Fix Helper" încorporat sunt acum sincronizate. Acest lucru este folosit pentru a preveni conectarea accidentală a "Mac Mouse Fix" la versiuni vechi ale "Mac Mouse Fix Helper".
- Am reparat problema unde unele date despre licență și perioada de probă erau uneori afișate incorect la prima pornire a aplicației prin eliminarea datelor cache din configurația inițială
- Multe curățări ale structurii proiectului și codului sursă
- Am îmbunătățit mesajele de debug

---

### Cum poți ajuta

Poți ajuta împărtășind **ideile**, **problemele** și **feedback-ul** tău!

Cel mai bun loc pentru a împărtăși **ideile** și **problemele** tale este [Asistentul de Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Cel mai bun loc pentru a oferi feedback **rapid** nestructurat este [Discuția de Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Poți accesa aceste locuri și din aplicație în fila "**ⓘ Despre**".

**Mulțumesc** că ajuți la îmbunătățirea Mac Mouse Fix! 💙💛❤️