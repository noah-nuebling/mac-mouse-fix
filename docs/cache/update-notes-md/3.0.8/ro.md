Mac Mouse Fix **3.0.8** rezolvă probleme de interfață și altele.

### **Probleme de interfață**

- Am dezactivat noul design pe macOS 26 Tahoe. Acum aplicația va arăta și va funcționa ca pe macOS 15 Sequoia.
    - Am făcut asta deoarece unele dintre elementele de interfață reproiectate de Apple încă au probleme. De exemplu, butoanele '-' de pe tab-ul 'Butoane' nu erau întotdeauna clickabile.
    - Interfața poate arăta puțin depășită pe macOS 26 Tahoe acum. Dar ar trebui să fie complet funcțională și rafinată ca înainte.
- Am rezolvat un bug unde notificarea 'Zilele gratuite s-au terminat' rămânea blocată în colțul din dreapta-sus al ecranului.
    - Mulțumiri lui [Sashpuri](https://github.com/Sashpuri) și altora pentru raportare!

### **Rafinări de interfață**

- Am dezactivat butonul verde de trafic din fereastra principală Mac Mouse Fix.
    - Butonul nu făcea nimic, deoarece fereastra nu poate fi redimensionată manual.
- Am rezolvat o problemă unde unele dintre liniile orizontale din tabelul de pe tab-ul 'Butoane' erau prea întunecate pe macOS 26 Tahoe.
- Am rezolvat un bug unde mesajul "Butonul principal al mouse-ului nu poate fi folosit" de pe tab-ul 'Butoane' era uneori tăiat pe macOS 26 Tahoe.
- Am corectat o greșeală de scriere în interfața în limba germană. Cu amabilitatea utilizatorului GitHub [i-am-the-slime](https://github.com/i-am-the-slime). Mulțumesc!
- Am rezolvat o problemă unde fereastra MMF clipea uneori scurt la dimensiunea greșită când deschideai fereastra pe macOS 26 Tahoe.

### **Alte modificări**

- Am îmbunătățit comportamentul când încerci să activezi Mac Mouse Fix în timp ce rulează mai multe instanțe ale Mac Mouse Fix pe computer.
    - Mac Mouse Fix va încerca acum să dezactiveze cealaltă instanță a Mac Mouse Fix mai diligent.
    - Acest lucru poate îmbunătăți cazurile limită în care Mac Mouse Fix nu putea fi activat.
- Modificări și curățare în fundal.

---

Verifică și ce este nou în versiunea anterioară [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).