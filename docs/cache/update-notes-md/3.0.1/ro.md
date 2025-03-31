Mac Mouse Fix **3.0.1** aduce mai multe remedieri de erori și îmbunătățiri, împreună cu o **nouă limbă**!

### S-a adăugat limba vietnameză!

Mac Mouse Fix este acum disponibil în 🇻🇳 vietnameză. Mulțumiri speciale lui @nghlt [de pe GitHub](https://GitHub.com/nghlt)!


### Remedieri de erori

- Mac Mouse Fix funcționează acum corect cu **Comutarea Rapidă între Utilizatori**!
  - Comutarea Rapidă între Utilizatori este când te conectezi la un al doilea cont macOS fără a te deconecta din primul cont.
  - Înainte de această actualizare, derularea nu mai funcționa după o comutare rapidă între utilizatori. Acum totul ar trebui să funcționeze corect.
- S-a remediat un mic bug unde aspectul filei Butoane era prea lat după prima pornire a Mac Mouse Fix.
- Câmpul '+' funcționează acum mai fiabil când adaugi mai multe Acțiuni în succesiune rapidă.
- S-a remediat o eroare obscură raportată de @V-Coba în Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Alte îmbunătățiri

- **Derularea se simte mai receptivă** când folosești setarea 'Fluiditate: Normală'.
  - Viteza animației devine acum mai rapidă pe măsură ce miști rotița mai repede. Astfel, se simte mai receptiv când derulezi rapid în timp ce rămâne la fel de fluid când derulezi încet.
  
- **Accelerarea vitezei de derulare** este acum mai stabilă și previzibilă.
- S-a implementat un mecanism pentru a **păstra setările** când actualizezi la o nouă versiune Mac Mouse Fix.
  - Înainte, Mac Mouse Fix reseta toate setările după actualizarea la o nouă versiune, dacă structura setărilor se schimba. Acum, Mac Mouse Fix va încerca să actualizeze structura setărilor tale și să-ți păstreze preferințele.
  - Deocamdată, acest lucru funcționează doar la actualizarea de la 3.0.0 la 3.0.1. Dacă actualizezi de la o versiune mai veche decât 3.0.0, sau dacă _retrogradezi_ de la 3.0.1 _la_ o versiune anterioară, setările tale vor fi în continuare resetate.
- Aspectul filei Butoane se adaptează acum mai bine în lățime pentru diferite limbi.
- Îmbunătățiri aduse [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) și altor documente.
- Sisteme de localizare îmbunătățite. Fișierele de traducere sunt acum curățate și analizate automat pentru potențiale probleme. Există un nou [Ghid de Localizare](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) care prezintă orice probleme detectate automat împreună cu alte informații utile și instrucțiuni pentru persoanele care vor să ajute la traducerea Mac Mouse Fix. S-a eliminat dependența de instrumentul [BartyCrouch](https://github.com/FlineDev/BartyCrouch) care era folosit anterior pentru a obține o parte din această funcționalitate.
- S-au îmbunătățit mai multe texte din interfață în engleză și germană.
- Multe îmbunătățiri și curățări în cod.

---

Vezi și notele de lansare pentru [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - cea mai mare actualizare a Mac Mouse Fix de până acum!