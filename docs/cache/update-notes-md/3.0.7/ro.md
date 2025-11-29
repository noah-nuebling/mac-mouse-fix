Mac Mouse Fix **3.0.7** rezolvă mai multe bug-uri importante.

### Remedieri de bug-uri

- Aplicația funcționează din nou pe **versiuni mai vechi de macOS** (macOS 10.15 Catalina și macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 nu putea fi activat pe acele versiuni de macOS deoarece funcția îmbunătățită 'Înapoi' și 'Înainte' introdusă în Mac Mouse Fix 3.0.6 încerca să folosească API-uri de sistem macOS care nu erau disponibile.
- Rezolvate problemele cu funcția **'Înapoi' și 'Înainte'**
    - Funcția îmbunătățită 'Înapoi' și 'Înainte' introdusă în Mac Mouse Fix 3.0.6 va folosi acum întotdeauna 'thread-ul principal' pentru a întreba macOS despre ce taste să simuleze pentru a merge înapoi și înainte în aplicația pe care o folosești. \
    Acest lucru poate preveni crash-urile și comportamentul nesigur în unele situații.
- Încercare de remediere a bug-ului în care **setările erau resetate aleatoriu**  (Vezi aceste [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Am rescris codul care încarcă fișierul de configurare pentru Mac Mouse Fix pentru a fi mai robust. Când apăreau erori rare ale sistemului de fișiere macOS, codul vechi putea uneori să creadă greșit că fișierul de configurare era corupt și să-l reseteze la valorile implicite.
- Reduse șansele unui bug în care **derularea se oprește din funcționare**     
     - Acest bug nu poate fi rezolvat complet fără modificări mai profunde, care probabil ar cauza alte probleme. \
      Totuși, deocamdată, am redus fereastra de timp în care poate apărea un 'deadlock' în sistemul de derulare, ceea ce ar trebui să scadă cel puțin șansele de a întâlni acest bug. Acest lucru face, de asemenea, derularea puțin mai eficientă. 
    - Acest bug are simptome similare – dar cred că o cauză de bază diferită – față de bug-ul 'Derularea se oprește intermitent' care a fost abordat în ultima versiune 3.0.6.
    - (Mulțumiri lui Joonas pentru diagnosticare!) 

Mulțumim tuturor pentru raportarea bug-urilor! 

---

Verifică și versiunea anterioară [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).