Mac Mouse Fix **3.0.4** îmbunătățește confidențialitatea, eficiența și fiabilitatea.\
Introduce un nou sistem de licențiere offline și rezolvă mai multe bug-uri importante.

### Confidențialitate și Eficiență Îmbunătățite

3.0.4 introduce un nou sistem de validare a licențelor offline care minimizează conexiunile la internet cât mai mult posibil.\
Acest lucru îmbunătățește confidențialitatea și economisește resursele sistemului computerului tău.\
Când este licențiată, aplicația funcționează acum 100% offline!

<details>
<summary><b>Click aici pentru mai multe detalii</b></summary>
Versiunile anterioare validau licențele online la fiecare lansare, permițând potențial stocarea jurnalelor de conexiune de către servere terțe (GitHub și Gumroad). Noul sistem elimină conexiunile inutile – după activarea inițială a licenței, se conectează la internet doar dacă datele locale ale licenței sunt corupte.
<br><br>
Deși niciun comportament al utilizatorilor nu a fost înregistrat vreodată de mine personal, sistemul anterior permitea teoretic serverelor terțe să înregistreze adresele IP și orele de conexiune. Gumroad putea de asemenea să înregistreze cheia ta de licență și potențial să o coreleze cu orice informații personale pe care le-au înregistrat despre tine când ai cumpărat Mac Mouse Fix.
<br><br>
Nu am luat în considerare aceste probleme subtile de confidențialitate când am construit sistemul original de licențiere, dar acum, Mac Mouse Fix este cât mai privat și fără internet posibil!
<br><br>
Vezi și <a href=https://gumroad.com/privacy>politica de confidențialitate a Gumroad</a> și acest <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>comentariu GitHub</a> al meu.

</details>

### Remedieri de Bug-uri

- Remediat un bug în care macOS se bloca uneori când se folosea 'Click and Drag' pentru 'Spaces & Mission Control'.
- Remediat un bug în care scurtăturile de tastatură din System Settings se ștergeau uneori când se foloseau acțiunile 'Click' din Mac Mouse Fix precum 'Mission Control'.
- Remediat [un bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) în care aplicația se oprea uneori și afișa o notificare că 'Zilele gratuite s-au terminat' utilizatorilor care cumpăraseră deja aplicația.
    - Dacă ai întâmpinat acest bug, îmi cer sincer scuze pentru neplăcere. Poți solicita o [rambursare aici](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Îmbunătățit modul în care aplicația recuperează fereastra sa principală, ceea ce ar fi putut remedia un bug în care ecranul 'Activate License' nu apărea uneori.

### Îmbunătățiri de Utilizabilitate

- Făcut imposibilă introducerea spațiilor și a liniilor noi în câmpul de text de pe ecranul 'Activate License'.
    - Acesta era un punct comun de confuzie, deoarece este foarte ușor să selectezi accidental o linie nouă ascunsă când copiezi cheia ta de licență din emailurile Gumroad.
- Aceste note de actualizare sunt traduse automat pentru utilizatorii non-englezi (Powered by Claude). Sper că este util! Dacă întâmpini probleme cu aceasta, anunță-mă. Aceasta este o primă privire asupra unui nou sistem de traducere pe care l-am dezvoltat în ultimul an.

### Suport (Neoficial) Abandonat pentru macOS 10.14 Mojave

Mac Mouse Fix 3 suportă oficial macOS 11 Big Sur și versiuni ulterioare. Totuși, pentru utilizatorii dispuși să accepte unele probleme și erori grafice, Mac Mouse Fix 3.0.3 și versiunile anterioare puteau fi încă folosite pe macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 abandonează acest suport și **acum necesită macOS 10.15 Catalina**. \
Îmi cer scuze pentru orice neplăcere cauzată de aceasta. Această schimbare mi-a permis să implementez sistemul îmbunătățit de licențiere folosind funcții moderne Swift. Utilizatorii Mojave pot continua să folosească Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) sau [ultima versiune a Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Sper că aceasta este o soluție bună pentru toată lumea.

### Îmbunătățiri Sub Capotă

- Implementat un nou sistem 'MFDataClass' care permite modelare de date mai puternică, menținând în același timp fișierul de configurare al Mac Mouse Fix lizibil și editabil de către oameni.
- Construit suport pentru adăugarea de platforme de plată altele decât Gumroad. Așa că în viitor, ar putea exista checkout-uri localizate, iar aplicația ar putea fi vândută în diferite țări.
- Îmbunătățit logging-ul care îmi permite să creez "Debug Builds" mai eficiente pentru utilizatorii care experimentează bug-uri greu de reprodus.
- Multe alte îmbunătățiri mici și lucrări de curățare.

*Editat cu asistență excelentă de la Claude.*

---

Verifică și versiunea anterioară [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).