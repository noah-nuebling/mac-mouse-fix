Mac Mouse Fix **3.0.7** risolve diversi bug importanti.

### Correzioni di Bug

- L'app funziona di nuovo su **versioni più vecchie di macOS** (macOS 10.15 Catalina e macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 non poteva essere abilitato su quelle versioni di macOS perché la funzione migliorata 'Indietro' e 'Avanti' introdotta in Mac Mouse Fix 3.0.6 tentava di utilizzare API di sistema di macOS che non erano disponibili.
- Risolti problemi con la funzione **'Indietro' e 'Avanti'**
    - La funzione migliorata 'Indietro' e 'Avanti' introdotta in Mac Mouse Fix 3.0.6 ora utilizzerà sempre il 'thread principale' per chiedere a macOS quali tasti simulare per andare indietro e avanti nell'app che stai usando. \
    Questo può prevenire crash e comportamenti inaffidabili in alcune situazioni.
- Tentativo di correggere il bug in cui **le impostazioni venivano ripristinate casualmente**  (Vedi queste [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Ho riscritto il codice che carica il file di configurazione per Mac Mouse Fix per renderlo più robusto. Quando si verificavano rari errori del file-system di macOS, il vecchio codice poteva a volte pensare erroneamente che il file di configurazione fosse corrotto e ripristinarlo alle impostazioni predefinite.
- Ridotte le probabilità di un bug in cui **lo scrolling smette di funzionare**     
     - Questo bug non può essere risolto completamente senza modifiche più profonde, che probabilmente causerebbero altri problemi. \
      Tuttavia, per il momento, ho ridotto la finestra temporale in cui può verificarsi un 'deadlock' nel sistema di scrolling, il che dovrebbe almeno ridurre le probabilità di incontrare questo bug. Questo rende anche lo scrolling leggermente più efficiente. 
    - Questo bug ha sintomi simili – ma penso una causa sottostante diversa – al bug 'Scroll Stops Working Intermittently' che è stato affrontato nell'ultima versione 3.0.6.
    - (Grazie a Joonas per la diagnostica!) 

Grazie a tutti per aver segnalato i bug! 

---

Dai un'occhiata anche alla versione precedente [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).