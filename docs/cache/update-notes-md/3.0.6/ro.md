Mac Mouse Fix **3.0.6** face funcția 'Înapoi' și 'Înainte' compatibilă cu mai multe aplicații.
De asemenea, rezolvă mai multe bug-uri și probleme.

### Funcția 'Înapoi' și 'Înainte' îmbunătățită

Mapările butoanelor mouse-ului pentru 'Înapoi' și 'Înainte' **funcționează acum în mai multe aplicații**, inclusiv:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed și alte editoare de cod
- Multe aplicații Apple integrate, precum Preview, Notes, System Settings, App Store și Music
- Adobe Acrobat
- Zotero
- Și multe altele!

Implementarea este inspirată de excelenta funcție 'Universal Back and Forward' din [LinearMouse](https://github.com/linearmouse/linearmouse). Ar trebui să suporte toate aplicațiile pe care le suportă LinearMouse. \
În plus, suportă unele aplicații care în mod normal necesită comenzi rapide de la tastatură pentru a merge înapoi și înainte, precum System Settings, App Store, Apple Notes și Adobe Acrobat. Mac Mouse Fix va detecta acum aceste aplicații și va simula comenzile rapide de la tastatură corespunzătoare.

Fiecare aplicație care a fost vreodată [solicitată într-un GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) ar trebui să fie suportată acum! (Mulțumim pentru feedback!) \
Dacă găsești aplicații care nu funcționează încă, anunță-mă printr-o [solicitare de funcționalitate](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Rezolvarea bug-ului 'Scroll-ul se oprește intermitent'

Unii utilizatori au întâmpinat o [problemă](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) în care **scroll-ul lin se oprește** aleatoriu.

Deși nu am reușit niciodată să reproduc problema, am implementat o posibilă soluție:

Aplicația va reîncerca acum de mai multe ori când configurarea sincronizării cu display-ul eșuează. \
Dacă tot nu funcționează după reîncercări, aplicația va:

- Reporni procesul de fundal 'Mac Mouse Fix Helper', ceea ce ar putea rezolva problema
- Genera un raport de crash, care ar putea ajuta la diagnosticarea bug-ului

Sper că problema este rezolvată acum! Dacă nu, anunță-mă printr-un [raport de bug](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) sau prin [email](http://redirect.macmousefix.com/?target=mailto-noah).



### Comportament îmbunătățit al rotii de scroll cu rotire liberă

Mac Mouse Fix **nu va mai accelera scroll-ul** pentru tine când lași roata de scroll să se rotească liber pe mouse-ul MX Master. (Sau orice alt mouse cu roată de scroll cu rotire liberă.)

Deși această funcție de 'accelerare a scroll-ului' este utilă pe rotile de scroll obișnuite, pe o roată de scroll cu rotire liberă poate face lucrurile mai greu de controlat.

**Notă:** Mac Mouse Fix nu este în prezent pe deplin compatibil cu majoritatea mouse-urilor Logitech, inclusiv MX Master. Plănuiesc să adaug suport complet, dar probabil va dura ceva timp. Între timp, cel mai bun driver terță parte cu suport Logitech pe care îl cunosc este [SteerMouse](https://plentycom.jp/en/steermouse/).





### Remedieri de bug-uri

- Rezolvată o problemă în care Mac Mouse Fix reactiva uneori comenzi rapide de la tastatură care fuseseră dezactivate anterior în System Settings  
- Rezolvat un crash la apăsarea pe 'Activate License' 
- Rezolvat un crash la apăsarea pe 'Cancel' imediat după apăsarea pe 'Activate License' (Mulțumim pentru raport, Ali!)
- Rezolvate crash-uri la încercarea de a folosi Mac Mouse Fix când niciun display nu este conectat la Mac-ul tău 
- Rezolvată o scurgere de memorie și alte probleme interne la comutarea între tab-uri în aplicație 

### Îmbunătățiri vizuale

- Rezolvată o problemă în care tab-ul About era uneori prea înalt, problemă introdusă în [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Textul de pe notificarea 'Free days are over' nu mai este tăiat în chineză
- Rezolvat un glitch vizual pe umbra câmpului '+' după înregistrarea unui input
- Rezolvat un glitch rar în care textul placeholder de pe ecranul 'Enter Your License Key' apărea decentrat
- Rezolvată o problemă în care unele simboluri afișate în aplicație aveau culoarea greșită după comutarea între modul întunecat/luminos

### Alte îmbunătățiri

- Făcute unele animații, precum animația de comutare între tab-uri, ușor mai eficiente  
- Dezactivată completarea automată a textului pe Touch Bar pe ecranul 'Enter Your License Key' 
- Diverse îmbunătățiri interne minore

*Editat cu asistență excelentă de la Claude.*

---

Verifică și versiunea anterioară [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).