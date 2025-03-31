De asemenea, verifică **lucrurile interesante** introduse în [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

Mac Mouse Fix **2.2.0** include diverse îmbunătățiri de utilizare și remedieri de erori!

### Remaparea la tastele funcționale exclusive Apple este acum mai bună

Ultima actualizare, 2.1.0, a introdus o nouă funcție interesantă care îți permite să remapezi butoanele mouse-ului la orice tastă de pe tastatură - chiar și taste funcționale care se găsesc doar pe tastaturile Apple. 2.2.0 aduce îmbunătățiri și rafinări suplimentare acestei funcții:

- Acum poți ține apăsat Option (⌥) pentru a remapa la taste care se găsesc doar pe tastaturile Apple - chiar dacă nu ai o tastatură Apple la îndemână.
- Simbolurile tastelor funcționale au un aspect îmbunătățit, integrându-se mai bine cu restul textului.
- Posibilitatea de remapare la Caps Lock a fost dezactivată. Nu funcționa conform așteptărilor.

### Adaugă / elimină Acțiuni mai ușor

Unii utilizatori au avut dificultăți în a înțelege că pot adăuga și elimina Acțiuni din Tabelul de Acțiuni. Pentru a face lucrurile mai ușor de înțeles, 2.2.0 include următoarele modificări și funcții noi:

- Acum poți șterge Acțiuni prin clic dreapta pe ele.
  - Acest lucru ar trebui să facă mai ușor de descoperit opțiunea de ștergere a Acțiunilor.
  - Meniul de clic dreapta include un simbol al butonului '-'. Acest lucru ar trebui să atragă atenția asupra butonului '-', care la rândul său ar trebui să atragă atenția asupra butonului '+'. Astfel, sperăm că opțiunea de **adăugare** a Acțiunilor devine mai ușor de descoperit.
- Acum poți adăuga Acțiuni în Tabelul de Acțiuni prin clic dreapta pe un rând gol.
- Butonul '-' este acum activ doar când o Acțiune este selectată. Acest lucru ar trebui să clarifice faptul că butonul '-' șterge Acțiunea selectată.
- Înălțimea implicită a ferestrei a fost mărită astfel încât să existe un rând gol vizibil pe care se poate face clic dreapta pentru a adăuga o Acțiune.
- Butoanele '+' și '-' au acum tooltipuri.

### Îmbunătățiri pentru Click și Drag

Pragul pentru activarea Click și Drag a fost mărit de la 5 pixeli la 7 pixeli. Acest lucru face mai dificilă activarea accidentală a Click și Drag, permițând în același timp utilizatorilor să schimbe Spațiile etc. folosind mișcări mici, confortabile.

### Alte modificări ale interfeței

- Aspectul Tabelului de Acțiuni a fost îmbunătățit.
- Diverse alte îmbunătățiri ale interfeței.

### Remedieri de erori

- S-a rezolvat o problemă în care interfața nu era estompată când MMF era pornit în timp ce era dezactivat.
- S-a eliminat opțiunea ascunsă "Button 3 Click and Drag".
  - La selectarea acesteia, aplicația se bloca. Am construit această opțiune pentru a face Mac Mouse Fix mai compatibil cu Blender. Dar în forma sa actuală, nu este foarte utilă pentru utilizatorii Blender deoarece nu poate fi combinată cu modificatori de tastatură. Planific să îmbunătățesc compatibilitatea cu Blender într-o versiune viitoare.