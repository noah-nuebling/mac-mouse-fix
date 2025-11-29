Mac Mouse Fix **3.0.3** è pronto per macOS 15 Sequoia. Risolve anche alcuni problemi di stabilità e fornisce diversi piccoli miglioramenti.

### Supporto per macOS 15 Sequoia

L'app ora funziona correttamente su macOS 15 Sequoia!

- La maggior parte delle animazioni dell'interfaccia non funzionavano su macOS 15 Sequoia. Ora tutto funziona di nuovo correttamente!
- Il codice sorgente è ora compilabile su macOS 15 Sequoia. Prima c'erano problemi con il compilatore Swift che impedivano la compilazione dell'app.

### Risoluzione dei crash durante lo scorrimento

Da Mac Mouse Fix 3.0.2 ci sono state [diverse segnalazioni](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) di Mac Mouse Fix che si disabilitava e riabilitava periodicamente durante lo scorrimento. Questo era causato da crash dell'app in background 'Mac Mouse Fix Helper'. Questo aggiornamento tenta di risolvere questi crash, con le seguenti modifiche:

- Il meccanismo di scorrimento cercherà di recuperare e continuare a funzionare invece di crashare, quando incontra il caso limite che sembra aver causato questi crash.
- Ho modificato il modo in cui vengono gestiti gli stati imprevisti nell'app in modo più generale: invece di crashare sempre immediatamente, l'app ora cercherà di recuperare dagli stati imprevisti in molti casi.
    
    - Questa modifica contribuisce alle correzioni per i crash durante lo scorrimento descritti sopra. Potrebbe anche prevenire altri crash.
  
Nota: non sono mai riuscito a riprodurre questi crash sulla mia macchina, e non sono ancora sicuro di cosa li abbia causati, ma in base alle segnalazioni che ho ricevuto, questo aggiornamento dovrebbe prevenire qualsiasi crash. Se riscontri ancora crash durante lo scorrimento o se *hai* riscontrato crash con la versione 3.0.2, sarebbe utile se condividessi la tua esperienza e i dati diagnostici nella Issue GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Questo mi aiuterebbe a capire il problema e migliorare Mac Mouse Fix. Grazie!

### Risoluzione degli scatti durante lo scorrimento

Nella versione 3.0.2 ho apportato modifiche al modo in cui Mac Mouse Fix invia gli eventi di scorrimento al sistema nel tentativo di ridurre gli scatti durante lo scorrimento probabilmente causati da problemi con le API VSync di Apple.

Tuttavia, dopo test più approfonditi e feedback, sembra che il nuovo meccanismo nella 3.0.2 renda lo scorrimento più fluido in alcuni scenari ma più scattoso in altri. Specialmente in Firefox sembrava essere notevolmente peggiore. \
Nel complesso, non era chiaro che il nuovo meccanismo migliorasse effettivamente gli scatti durante lo scorrimento in tutti i casi. Inoltre, potrebbe aver contribuito ai crash durante lo scorrimento descritti sopra.

Per questo motivo ho disabilitato il nuovo meccanismo e ripristinato il meccanismo VSync per gli eventi di scorrimento a come era in Mac Mouse Fix 3.0.0 e 3.0.1.

Vedi la Issue GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) per maggiori informazioni.

### Rimborso

Mi dispiace per i problemi relativi alle modifiche dello scorrimento nelle versioni 3.0.1 e 3.0.2. Ho sottovalutato enormemente i problemi che ne sarebbero derivati, e sono stato lento nell'affrontare questi problemi. Farò del mio meglio per imparare da questa esperienza ed essere più attento con tali modifiche in futuro. Vorrei anche offrire un rimborso a chiunque sia stato colpito. Clicca semplicemente [qui](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) se sei interessato.

### Meccanismo di aggiornamento più intelligente

Queste modifiche sono state portate da Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) e [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Dai un'occhiata alle loro note di rilascio per saperne di più sui dettagli. Ecco un riepilogo:

- C'è un nuovo meccanismo più intelligente che decide quale aggiornamento mostrare all'utente.
- Passaggio dall'uso del framework di aggiornamento Sparkle 1.26.0 all'ultima versione Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- La finestra che l'app mostra per informarti che è disponibile una nuova versione di Mac Mouse Fix ora supporta JavaScript, che consente una formattazione migliore delle note di aggiornamento.

### Altri miglioramenti e correzioni di bug

- Risolto un problema per cui il prezzo dell'app e le informazioni correlate venivano visualizzati in modo errato nella scheda 'Informazioni' in alcuni casi.
- Risolto un problema per cui il meccanismo di sincronizzazione dello scorrimento fluido con la frequenza di aggiornamento del display non funzionava correttamente quando si utilizzavano più display.
- Molte piccole pulizie e miglioramenti interni.

---

Dai un'occhiata anche alla versione precedente [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).