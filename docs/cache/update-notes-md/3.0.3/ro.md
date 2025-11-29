Mac Mouse Fix **3.0.3** este gata pentru macOS 15 Sequoia. De asemenea, rezolvă câteva probleme de stabilitate și oferă mai multe îmbunătățiri minore.

### Suport pentru macOS 15 Sequoia

Aplicația funcționează acum corect pe macOS 15 Sequoia!

- Majoritatea animațiilor din interfață erau defecte pe macOS 15 Sequoia. Acum totul funcționează din nou corect!
- Codul sursă poate fi acum compilat pe macOS 15 Sequoia. Înainte, existau probleme cu compilatorul Swift care împiedicau compilarea aplicației.

### Rezolvarea crash-urilor la derulare

De la Mac Mouse Fix 3.0.2 au existat [multiple raportări](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) despre faptul că Mac Mouse Fix se dezactivează și se reactivează periodic în timpul derulării. Acest lucru era cauzat de crash-uri ale aplicației de fundal 'Mac Mouse Fix Helper'. Această actualizare încearcă să rezolve aceste crash-uri, cu următoarele modificări:

- Mecanismul de derulare va încerca să se recupereze și să continue să funcționeze în loc să se blocheze, când întâlnește cazul limită care pare să fi dus la aceste crash-uri.
- Am schimbat modul în care sunt gestionate stările neașteptate în aplicație în general: În loc să se blocheze întotdeauna imediat, aplicația va încerca acum să se recupereze din stări neașteptate în multe cazuri.
    
    - Această modificare contribuie la rezolvarea crash-urilor la derulare descrise mai sus. Ar putea preveni și alte crash-uri.
  
Notă: Nu am putut niciodată să reproduc aceste crash-uri pe computerul meu și încă nu sunt sigur ce le-a cauzat, dar pe baza raportărilor primite, această actualizare ar trebui să prevină orice crash-uri. Dacă încă mai întâmpini crash-uri în timpul derulării sau dacă *ai* întâmpinat crash-uri în versiunea 3.0.2, ar fi valoros dacă ai împărtăși experiența ta și datele de diagnosticare în GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Acest lucru m-ar ajuta să înțeleg problema și să îmbunătățesc Mac Mouse Fix. Mulțumesc!

### Rezolvarea întreruperilor la derulare

În 3.0.2 am făcut modificări la modul în care Mac Mouse Fix trimite evenimente de derulare către sistem într-o încercare de a reduce întreruperile la derulare probabil cauzate de probleme cu API-urile VSync de la Apple.

Totuși, după testări mai extinse și feedback, se pare că noul mecanism din 3.0.2 face derularea mai fluidă în unele scenarii, dar mai întreruptă în altele. Mai ales în Firefox părea să fie vizibil mai rău. \
Per total, nu era clar că noul mecanism îmbunătățea efectiv întreruperile la derulare în general. De asemenea, ar fi putut contribui la crash-urile la derulare descrise mai sus.

De aceea am dezactivat noul mecanism și am revenit mecanismul VSync pentru evenimentele de derulare la cum era în Mac Mouse Fix 3.0.0 și 3.0.1.

Vezi GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) pentru mai multe informații.

### Rambursare

Îmi pare rău pentru problemele legate de modificările la derulare din 3.0.1 și 3.0.2. Am subestimat enorm problemele care ar veni cu asta și am fost lent în a aborda aceste probleme. Voi face tot posibilul să învăț din această experiență și să fiu mai atent cu astfel de modificări în viitor. Aș dori, de asemenea, să ofer o rambursare oricui a fost afectat. Doar dă click [aici](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) dacă ești interesat.

### Mecanism de actualizare mai inteligent

Aceste modificări au fost aduse din Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) și [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consultă notele lor de lansare pentru a afla mai multe despre detalii. Iată un rezumat:

- Există un nou mecanism mai inteligent care decide ce actualizare să fie afișată utilizatorului.
- Am trecut de la utilizarea framework-ului de actualizare Sparkle 1.26.0 la cel mai recent Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- Fereastra pe care aplicația o afișează pentru a te informa că o nouă versiune de Mac Mouse Fix este disponibilă suportă acum JavaScript, ceea ce permite o formatare mai plăcută a notelor de actualizare.

### Alte îmbunătățiri și remedieri de erori

- Am rezolvat o problemă în care prețul aplicației și informațiile conexe erau afișate incorect pe fila 'Despre' în unele cazuri.
- Am rezolvat o problemă în care mecanismul de sincronizare a derulării fluide cu rata de reîmprospătare a ecranului nu funcționa corect când se foloseau mai multe ecrane.
- Multe curățări și îmbunătățiri minore în fundal.

---

Consultă și versiunea anterioară [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).