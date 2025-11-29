Mac Mouse Fix **3.0.8** risolve problemi dell'interfaccia e altro.

### **Problemi dell'interfaccia**

- Disabilitato il nuovo design su macOS 26 Tahoe. Ora l'app avrà l'aspetto e funzionerà come su macOS 15 Sequoia.
    - L'ho fatto perché alcuni elementi dell'interfaccia ridisegnati da Apple hanno ancora problemi. Ad esempio, i pulsanti '-' nella scheda 'Pulsanti' non erano sempre cliccabili.
    - L'interfaccia potrebbe sembrare un po' datata su macOS 26 Tahoe ora. Ma dovrebbe essere completamente funzionale e rifinita come prima.
- Risolto un bug per cui la notifica 'I giorni gratuiti sono finiti' rimaneva bloccata nell'angolo in alto a destra dello schermo.
    - Grazie a [Sashpuri](https://github.com/Sashpuri) e altri per averlo segnalato!

### **Rifinitura dell'interfaccia**

- Disabilitato il pulsante del semaforo verde nella finestra principale di Mac Mouse Fix.
    - Il pulsante non faceva nulla, dato che la finestra non può essere ridimensionata manualmente.
- Risolto un problema per cui alcune delle linee orizzontali nella tabella della scheda 'Pulsanti' erano troppo scure su macOS 26 Tahoe.
- Risolto un bug per cui il messaggio "Il pulsante principale del mouse non può essere usato" nella scheda 'Pulsanti' veniva talvolta tagliato su macOS 26 Tahoe.
- Corretto un errore di battitura nell'interfaccia tedesca. Per gentile concessione dell'utente GitHub [i-am-the-slime](https://github.com/i-am-the-slime). Grazie!
- Risolto un problema per cui la finestra di MMF lampeggiava brevemente con dimensioni errate all'apertura su macOS 26 Tahoe.

### **Altre modifiche**

- Migliorato il comportamento quando si tenta di abilitare Mac Mouse Fix mentre sono in esecuzione più istanze di Mac Mouse Fix sul computer.
    - Mac Mouse Fix ora cercherà di disabilitare l'altra istanza di Mac Mouse Fix in modo più diligente.
    - Questo potrebbe migliorare casi limite in cui Mac Mouse Fix non poteva essere abilitato.
- Modifiche e pulizia interne.

---

Dai un'occhiata anche alle novità della versione precedente [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).