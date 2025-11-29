Mac Mouse Fix **3.0.5** corregge diversi bug, migliora le prestazioni e aggiunge un po' di rifinitura all'app. \
È anche compatibile con macOS 26 Tahoe.

### Simulazione Migliorata dello Scorrimento del Trackpad

- Il sistema di scorrimento ora può simulare un tocco con due dita sul trackpad per far smettere di scorrere le applicazioni.
    - Questo risolve un problema durante l'esecuzione di app per iPhone o iPad, dove lo scorrimento spesso continuava dopo che l'utente aveva scelto di fermarsi.
- Corretta la simulazione incoerente del sollevamento delle dita dal trackpad.
    - Questo potrebbe aver causato comportamenti non ottimali in alcune situazioni.



### Compatibilità con macOS 26 Tahoe

Quando si esegue la Beta di macOS 26 Tahoe, l'app è ora utilizzabile e la maggior parte dell'interfaccia funziona correttamente.



### Miglioramento delle Prestazioni

Migliorate le prestazioni del gesto Clic e Trascina per "Scorrere e Navigare". \
Nei miei test, l'utilizzo della CPU è stato ridotto di circa il 50%!

**Contesto**

Durante il gesto "Scorrere e Navigare", Mac Mouse Fix disegna un cursore del mouse finto in una finestra trasparente, bloccando il cursore del mouse reale in posizione. Questo assicura che tu possa continuare a scorrere l'elemento dell'interfaccia su cui hai iniziato a scorrere, indipendentemente da quanto lontano muovi il mouse.

Il miglioramento delle prestazioni è stato ottenuto disattivando la gestione predefinita degli eventi di macOS su questa finestra trasparente, che comunque non veniva utilizzata.





### Correzioni di Bug

- Ora vengono ignorati gli eventi di scorrimento dalle tavolette grafiche Wacom.
    - Prima, Mac Mouse Fix causava uno scorrimento irregolare sulle tavolette Wacom, come segnalato da @frenchie1980 nella Issue GitHub [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Grazie!)
    
- Corretto un bug in cui il codice Swift Concurrency, introdotto come parte del nuovo sistema di licenze in Mac Mouse Fix 3.0.4, non veniva eseguito sul thread corretto.
    - Questo causava crash su macOS Tahoe, e probabilmente causava anche altri bug sporadici relativi alle licenze.
- Migliorata la robustezza del codice che decodifica le licenze offline.
    - Questo aggira un problema nelle API di Apple che causava il fallimento costante della validazione delle licenze offline sul mio Mac Mini Intel. Presumo che questo accadesse su tutti i Mac Intel, e che fosse la ragione per cui il bug "Giorni gratuiti terminati" (già affrontato nella 3.0.4) si verificava ancora per alcune persone, come segnalato da @toni20k5267 nella Issue GitHub [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Grazie!)
        - Se hai riscontrato il bug "Giorni gratuiti terminati", mi dispiace! Puoi ottenere un rimborso [qui](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Miglioramenti dell'Esperienza Utente

- Disabilitati i dialoghi che fornivano soluzioni passo-passo per i bug di macOS che impedivano agli utenti di abilitare Mac Mouse Fix.
    - Questi problemi si verificavano solo su macOS 13 Ventura e 14 Sonoma. Ora, questi dialoghi appaiono solo su quelle versioni di macOS in cui sono rilevanti. 
    - I dialoghi sono anche un po' più difficili da attivare – prima, a volte apparivano in situazioni in cui non erano molto utili.
    
- Aggiunto un link "Attiva Licenza" direttamente sulla notifica "Giorni gratuiti terminati". 
    - Questo rende l'attivazione di una licenza Mac Mouse Fix ancora più semplice!

### Miglioramenti Visivi

- Leggermente migliorato l'aspetto della finestra "Aggiornamento Software". Ora si adatta meglio a macOS 26 Tahoe. 
    - Questo è stato fatto personalizzando l'aspetto predefinito del framework "Sparkle 1.27.3" che Mac Mouse Fix utilizza per gestire gli aggiornamenti.
- Risolto il problema in cui il testo in fondo alla scheda Informazioni veniva talvolta tagliato in cinese, rendendo la finestra leggermente più larga.
- Corretto il testo in fondo alla scheda Informazioni che era leggermente decentrato.
- Corretto un bug che causava uno spazio troppo piccolo sotto l'opzione "Scorciatoia da Tastiera..." nella scheda Pulsanti. 

### Modifiche Interne

- Rimossa la dipendenza dal framework "SnapKit".
    - Questo riduce leggermente la dimensione dell'app da 19,8 a 19,5 MB.
- Vari altri piccoli miglioramenti nel codice.

*Modificato con l'eccellente assistenza di Claude.*

---

Dai un'occhiata anche alla versione precedente [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).