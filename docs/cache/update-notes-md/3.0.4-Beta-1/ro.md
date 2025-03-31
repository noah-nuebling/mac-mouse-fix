Mac Mouse Fix **3.0.4 Beta 1** îmbunătățește confidențialitatea, eficiența și fiabilitatea.\
Introduce un nou sistem de licențiere offline și rezolvă mai multe probleme importante.

### Confidențialitate și Eficiență Îmbunătățite

- Introduce un nou sistem de validare a licenței offline care minimizează conexiunile la internet.
- Aplicația se conectează la internet doar când este absolut necesar, protejându-ți confidențialitatea și reducând utilizarea resurselor.
- Aplicația funcționează complet offline în timpul utilizării normale când este licențiată.

<details>
<summary><b>Informații Detaliate despre Confidențialitate</b></summary>
Versiunile anterioare validau licențele online la fiecare lansare, permițând potențial stocarea jurnalelor de conexiune de către servere terțe (GitHub și Gumroad). Noul sistem elimină conexiunile inutile – după activarea inițială a licenței, se conectează la internet doar dacă datele locale ale licenței sunt corupte.
<br><br>
Deși comportamentul utilizatorului nu a fost niciodată înregistrat de mine personal, sistemul anterior permitea teoretic serverelor terțe să înregistreze adresele IP și timpii de conectare. Gumroad putea de asemenea să înregistreze cheia ta de licență și potențial să o coreleze cu orice informație personală pe care au înregistrat-o despre tine când ai cumpărat Mac Mouse Fix.
<br><br>
Nu am luat în considerare aceste probleme subtile de confidențialitate când am construit sistemul original de licențiere, dar acum, Mac Mouse Fix este cât se poate de privat și independent de internet!
<br><br>
Vezi și <a href=https://gumroad.com/privacy>politica de confidențialitate Gumroad</a> și acest <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>comentariu</a> al meu de pe GitHub.

</details>

### Remedieri de Erori

- S-a rezolvat o eroare unde macOS se bloca uneori când se folosea 'Click and Drag' pentru 'Spaces & Mission Control'.
- S-a rezolvat o eroare unde scurtăturile de tastatură din Setări System erau uneori șterse când se folosea o acțiune 'Click' definită în Mac Mouse Fix precum 'Mission Control'.
- S-a rezolvat [o eroare](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) unde aplicația se oprea uneori din funcționare și afișa o notificare că 'Zilele gratuite s-au terminat' utilizatorilor care deja cumpăraseră aplicația.
    - Dacă ai întâmpinat această eroare, îmi cer sincer scuze pentru neplăcere. Poți solicita o [rambursare aici](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).

### Îmbunătățiri Tehnice

- S-a implementat un nou sistem 'MFDataClass' care permite modelarea mai clară a datelor și fișiere de configurare lizibile.
- S-a construit suport pentru adăugarea altor platforme de plată în afară de Gumroad. Astfel că în viitor, ar putea exista checkout-uri localizate, și aplicația ar putea fi vândută în diferite țări!

### S-a Renunțat la Suportul (Neoficial) pentru macOS 10.14 Mojave

Mac Mouse Fix 3 suportă oficial macOS 11 Big Sur și versiunile ulterioare. Totuși, pentru utilizatorii dispuși să accepte unele probleme și erori grafice, Mac Mouse Fix 3.0.3 și versiunile anterioare puteau fi încă utilizate pe macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 renunță la acest suport și **necesită acum macOS 10.15 Catalina**.\
Îmi cer scuze pentru orice neplăcere cauzată de această schimbare. Această modificare mi-a permis să implementez sistemul îmbunătățit de licențiere folosind funcționalități moderne Swift. Utilizatorii Mojave pot continua să folosească Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) sau [ultima versiune de Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Sper că aceasta este o soluție bună pentru toată lumea.

*Editat cu asistența excelentă de la Claude.*

---

Vezi și versiunea anterioară [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).