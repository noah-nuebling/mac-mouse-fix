**ℹ️ Nota per gli utenti di Mac Mouse Fix 2**

Con l'introduzione di Mac Mouse Fix 3, il modello di prezzo dell'app è cambiato:

- **Mac Mouse Fix 2**\
Rimane gratuito al 100% e ho intenzione di continuare a supportarlo.\
**Salta questo aggiornamento** per continuare a usare Mac Mouse Fix 2. Scarica l'ultima versione di Mac Mouse Fix 2 [qui](https://redirect.macmousefix.com/?target=mmf2-latest).
- **Mac Mouse Fix 3**\
Gratuito per 30 giorni, costa alcuni dollari per possederlo.\
**Aggiorna ora** per ottenere Mac Mouse Fix 3!

Puoi saperne di più sui prezzi e le funzionalità di Mac Mouse Fix 3 sul [nuovo sito web](https://macmousefix.com/).

Grazie per utilizzare Mac Mouse Fix! :)

---

**ℹ️ Nota per gli acquirenti di Mac Mouse Fix 3**

Se hai aggiornato accidentalmente a Mac Mouse Fix 3 senza sapere che non è più gratuito, vorrei offrirti un [rimborso](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

L'ultima versione di Mac Mouse Fix 2 rimane **completamente gratuita** e puoi scaricarla [qui](https://redirect.macmousefix.com/?target=mmf2-latest).

Mi dispiace per il disturbo e spero che questa soluzione vada bene per tutti!

---

Mac Mouse Fix **3.0.3** è pronto per macOS 15 Sequoia. Risolve anche alcuni problemi di stabilità e fornisce diversi piccoli miglioramenti.

### Supporto per macOS 15 Sequoia

L'app ora funziona correttamente su macOS 15 Sequoia!

- La maggior parte delle animazioni dell'interfaccia utente erano interrotte su macOS 15 Sequoia. Ora tutto funziona di nuovo correttamente!
- Il codice sorgente ora può essere compilato su macOS 15 Sequoia. Prima c'erano problemi con il compilatore Swift che impedivano la compilazione dell'app.

### Risoluzione dei crash durante lo scorrimento

Da Mac Mouse Fix 3.0.2 ci sono stati [diversi report](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) di Mac Mouse Fix che si disabilitava e riabilitava periodicamente durante lo scorrimento. Questo era causato da crash dell'app in background 'Mac Mouse Fix Helper'. Questo aggiornamento cerca di risolvere questi crash con le seguenti modifiche:

- Il meccanismo di scorrimento cercherà di recuperare e continuare a funzionare invece di crashare quando incontra il caso limite che sembra aver portato a questi crash.
- Ho cambiato il modo in cui vengono gestiti gli stati imprevisti nell'app più in generale: invece di crashare sempre immediatamente, l'app ora cercherà di recuperare da stati imprevisti in molti casi.

    - Questa modifica contribuisce alle correzioni per i crash di scorrimento descritti sopra. Potrebbe anche prevenire altri crash.

Nota a margine: Non sono mai riuscito a riprodurre questi crash sulla mia macchina e non sono ancora sicuro di cosa li abbia causati, ma in base ai report ricevuti, questo aggiornamento dovrebbe prevenire qualsiasi crash. Se riscontri ancora crash durante lo scorrimento o se hai riscontrato crash con la versione 3.0.2, sarebbe prezioso se condividessi la tua esperienza e i dati diagnostici nell'Issue GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Questo mi aiuterebbe a capire il problema e migliorare Mac Mouse Fix. Grazie!

### Risoluzione dei blocchi durante lo scorrimento

In 3.0.2 ho apportato modifiche al modo in cui Mac Mouse Fix invia eventi di scorrimento al sistema nel tentativo di ridurre i blocchi probabilmente causati da problemi con le API VSync di Apple.

Tuttavia, dopo test più approfonditi e feedback, sembra che il nuovo meccanismo in 3.0.2 renda lo scorrimento più fluido in alcuni scenari ma più irregolare in altri. Soprattutto in Firefox sembrava essere notevolmente peggiore.\
Nel complesso, non era chiaro che il nuovo meccanismo migliorasse effettivamente i blocchi di scorrimento in generale. Inoltre, potrebbe aver contribuito ai crash di scorrimento descritti sopra.

Per questo motivo ho disabilitato il nuovo meccanismo e riportato il meccanismo VSync per gli eventi di scorrimento a come era in Mac Mouse Fix 3.0.0 e 3.0.1.

Vedi l'Issue GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) per maggiori informazioni.

### Rimborso

Mi scuso per i problemi relativi alle modifiche allo scorrimento in 3.0.1 e 3.0.2. Ho enormemente sottovalutato i problemi che sarebbero emersi e sono stato lento nell'affrontare questi problemi. Farò del mio meglio per imparare da questa esperienza ed essere più attento con tali modifiche in futuro. Vorrei anche offrire un rimborso a chiunque sia stato colpito. Basta cliccare [qui](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) se sei interessato.

### Meccanismo di aggiornamento più intelligente

Queste modifiche sono state portate da Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) e [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consulta le loro note di rilascio per saperne di più sui dettagli. Ecco un riepilogo:

- C'è un nuovo meccanismo più intelligente che decide quale aggiornamento mostrare all'utente.
- Passaggio dal framework di aggiornamento Sparkle 1.26.0 all'ultimo Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- La finestra che l'app mostra per informarti che è disponibile una nuova versione di Mac Mouse Fix ora supporta JavaScript, che permette una formattazione più gradevole delle note di aggiornamento.

### Altri miglioramenti e correzioni di bug

- Risolto un problema per cui il prezzo dell'app e le informazioni correlate venivano visualizzate in modo errato nella scheda 'Informazioni' in alcuni casi.
- Risolto un problema per cui il meccanismo di sincronizzazione dello scorrimento fluido con la frequenza di aggiornamento del display non funzionava correttamente durante l'utilizzo di più display.
- Molte piccole pulizie e miglioramenti sotto il cofano.

---

Dai anche un'occhiata al precedente rilascio [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).