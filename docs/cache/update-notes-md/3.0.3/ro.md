**ℹ️ Notă pentru utilizatorii Mac Mouse Fix 2**

Odată cu introducerea Mac Mouse Fix 3, modelul de preț al aplicației s-a schimbat:

- **Mac Mouse Fix 2**\
Rămâne 100% gratuit și intenționez să continui să îl suport.\
**Sari peste această actualizare** pentru a continua să folosești Mac Mouse Fix 2. Descarcă ultima versiune a Mac Mouse Fix 2 [aici](https://redirect.macmousefix.com/?target=mmf2-latest).
- **Mac Mouse Fix 3**\
Gratuit pentru 30 de zile, costă câțiva dolari pentru a-l deține.\
**Actualizează acum** pentru a obține Mac Mouse Fix 3!

Poți afla mai multe despre prețurile și funcționalitățile Mac Mouse Fix 3 pe [noul website](https://macmousefix.com/).

Mulțumesc că folosești Mac Mouse Fix! :)

---

**ℹ️ Notă pentru cumpărătorii Mac Mouse Fix 3**

Dacă ai actualizat din greșeală la Mac Mouse Fix 3 fără să știi că nu mai este gratuit, aș dori să îți ofer o [rambursare](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

Ultima versiune a Mac Mouse Fix 2 rămâne **complet gratuită** și o poți descărca [aici](https://redirect.macmousefix.com/?target=mmf2-latest).

Îmi pare rău pentru neplăcere și sper că toată lumea este mulțumită cu această soluție!

---

Mac Mouse Fix **3.0.3** este pregătit pentru macOS 15 Sequoia. De asemenea, rezolvă câteva probleme de stabilitate și aduce mai multe îmbunătățiri minore.

### Suport pentru macOS 15 Sequoia

Aplicația funcționează acum corect pe macOS 15 Sequoia!

- Majoritatea animațiilor UI erau defecte pe macOS 15 Sequoia. Acum totul funcționează din nou corect!
- Codul sursă poate fi acum compilat pe macOS 15 Sequoia. Înainte, existau probleme cu compilatorul Swift care împiedicau compilarea aplicației.

### Rezolvarea crash-urilor la derulare

De la Mac Mouse Fix 3.0.2 au existat [multiple raportări](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) despre Mac Mouse Fix care se dezactiva și se reactiva periodic în timpul derulării. Acest lucru era cauzat de crash-uri ale aplicației de fundal 'Mac Mouse Fix Helper'. Această actualizare încearcă să rezolve aceste crash-uri prin următoarele modificări:

- Mecanismul de derulare va încerca să își revină și să continue să funcționeze în loc să se blocheze când întâlnește cazul particular care pare să fi dus la aceste crash-uri.
- Am modificat modul în care sunt gestionate stările neașteptate în aplicație în general: În loc să se blocheze imediat, aplicația va încerca acum să își revină din stările neașteptate în multe cazuri.

    - Această modificare contribuie la rezolvările crash-urilor la derulare descrise mai sus. Ar putea preveni și alte crash-uri.

Notă: Nu am putut reproduce niciodată aceste crash-uri pe mașina mea și încă nu sunt sigur ce le-a cauzat, dar bazat pe raportările primite, această actualizare ar trebui să prevină orice crash. Dacă încă experimentezi crash-uri în timpul derulării sau dacă *ai* experimentat crash-uri în versiunea 3.0.2, ar fi valoros să îți împărtășești experiența și datele de diagnosticare în Issue-ul GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Acest lucru m-ar ajuta să înțeleg problema și să îmbunătățesc Mac Mouse Fix. Mulțumesc!

### Rezolvarea sacadărilor la derulare

În 3.0.2 am făcut modificări în modul în care Mac Mouse Fix trimite evenimente de derulare către sistem într-o încercare de a reduce sacadările probabil cauzate de probleme cu API-urile VSync ale Apple.

Totuși, după teste mai extensive și feedback, se pare că noul mecanism din 3.0.2 face derularea mai fluidă în unele scenarii dar mai sacadată în altele. În special în Firefox părea să fie vizibil mai rău.\
Per total, nu era clar că noul mecanism îmbunătățea de fapt sacadările în general. De asemenea, ar fi putut contribui la crash-urile la derulare descrise mai sus.

De aceea am dezactivat noul mecanism și am revenit la mecanismul VSync pentru evenimentele de derulare așa cum era în Mac Mouse Fix 3.0.0 și 3.0.1.

Vezi Issue-ul GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) pentru mai multe informații.

### Rambursare

Îmi pare rău pentru problemele legate de modificările de derulare din 3.0.1 și 3.0.2. Am subestimat mult problemele care ar apărea din această cauză și am fost lent în rezolvarea acestor probleme. Voi face tot posibilul să învăț din această experiență și să fiu mai atent cu astfel de modificări pe viitor. Aș dori să ofer oricui a fost afectat o rambursare. Doar dă click [aici](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) dacă ești interesat.

### Mecanism de actualizare mai inteligent

Aceste modificări au fost preluate din Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) și [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Verifică notele lor de lansare pentru a afla mai multe despre detalii. Iată un rezumat:

- Există un nou mecanism mai inteligent care decide ce actualizare să arate utilizatorului.
- S-a trecut de la folosirea framework-ului de actualizare Sparkle 1.26.0 la cel mai recent Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- Fereastra pe care aplicația o afișează pentru a te informa că o nouă versiune a Mac Mouse Fix este disponibilă suportă acum JavaScript, ceea ce permite o formatare mai frumoasă a notelor de actualizare.

### Alte îmbunătățiri și rezolvări de bug-uri

- S-a rezolvat o problemă unde prețul aplicației și informațiile conexe erau afișate incorect în tab-ul 'About' în unele cazuri.
- S-a rezolvat o problemă unde mecanismul pentru sincronizarea derulării line cu rata de reîmprospătare a ecranului nu funcționa corect când se foloseau mai multe monitoare.
- Multe îmbunătățiri și curățări minore sub capotă.

---

Verifică și lansarea anterioară [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).