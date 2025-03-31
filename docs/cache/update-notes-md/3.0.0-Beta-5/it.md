Dai anche un'occhiata alle **interessanti novità** introdotte in [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

**3.0.0 Beta 5** ripristina la **compatibilità** con alcuni **mouse** su macOS 13 Ventura e **corregge lo scrolling** in molte app.
Include anche diverse altre piccole correzioni e miglioramenti della qualità.

Ecco **tutte le novità**:

### Mouse

- Risolto lo scrolling in Terminal e altre app! Vedi il problema GitHub [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Risolto il problema di incompatibilità con alcuni mouse su macOS 13 Ventura abbandonando l'uso di API Apple inaffidabili in favore di hack a basso livello. Spero che questo non introduca nuovi problemi - fatemi sapere se succede! Un ringraziamento speciale a Maria e all'utente GitHub [samiulhsnt](https://github.com/samiulhsnt) per aver aiutato a risolvere questo problema! Vedi il problema GitHub [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) per maggiori informazioni.
- Non utilizzerà più CPU quando si fa clic sul pulsante 1 o 2 del mouse. Leggermente ridotto l'utilizzo della CPU quando si fa clic su altri pulsanti.
    - Questa è una "Build di Debug" quindi l'utilizzo della CPU può essere circa 10 volte superiore quando si fa clic sui pulsanti in questa beta rispetto alla versione finale
- La simulazione dello scrolling del trackpad utilizzata per le funzioni "Smooth Scrolling" e "Scroll & Navigate" di Mac Mouse Fix è ora ancora più accurata. Questo potrebbe portare a un comportamento migliore in alcune situazioni.

### Interfaccia

- Correzione automatica dei problemi con la concessione dell'Accesso Accessibilità dopo l'aggiornamento da una versione precedente di Mac Mouse Fix. Adotta le modifiche descritte nelle [Note di rilascio 2.2.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Aggiunto un pulsante "Annulla" alla schermata "Concedi Accesso Accessibilità"
- Risolto un problema per cui la configurazione di Mac Mouse Fix non funzionava correttamente dopo l'installazione di una nuova versione di Mac Mouse Fix, perché la nuova versione si connetteva alla vecchia versione di "Mac Mouse Fix Helper". Ora, Mac Mouse Fix non si connetterà più al vecchio "Mac Mouse Fix Helper" e disabiliterà automaticamente la vecchia versione quando appropriato.
- Fornire all'utente istruzioni su come risolvere un problema per cui Mac Mouse Fix non può essere abilitato correttamente a causa della presenza di un'altra versione di Mac Mouse Fix nel sistema. Questo problema si verifica solo su macOS Ventura.
- Migliorati comportamento e animazioni nella schermata "Concedi Accesso Accessibilità"
- Mac Mouse Fix verrà portato in primo piano quando viene abilitato. Questo migliora le interazioni dell'interfaccia in alcune situazioni, come quando si abilita Mac Mouse Fix dopo che è stato disabilitato in Impostazioni di Sistema > Generale > Elementi Login.
- Migliorati i testi dell'interfaccia nella schermata "Concedi Accesso Accessibilità"
- Migliorati i testi dell'interfaccia che appaiono quando si cerca di abilitare Mac Mouse Fix mentre è disabilitato nelle Impostazioni di Sistema
- Corretto un testo dell'interfaccia in tedesco

### Sotto il cofano

- Il numero di build di "Mac Mouse Fix" e del "Mac Mouse Fix Helper" incorporato sono ora sincronizzati. Questo serve a impedire che "Mac Mouse Fix" si connetta accidentalmente a vecchie versioni di "Mac Mouse Fix Helper".
- Risolto un problema per cui alcuni dati relativi alla licenza e al periodo di prova venivano talvolta visualizzati in modo errato all'avvio dell'app per la prima volta, rimuovendo i dati della cache dalla configurazione iniziale
- Molte pulizie della struttura del progetto e del codice sorgente
- Migliorati i messaggi di debug

---

### Come Puoi Aiutare

Puoi aiutare condividendo le tue **idee**, **problemi** e **feedback**!

Il posto migliore per condividere le tue **idee** e **problemi** è l'[Assistente Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Il posto migliore per dare un feedback **veloce** e non strutturato è la [Discussione Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Puoi accedere a questi luoghi anche dall'app nella scheda "**ⓘ Info**".

**Grazie** per aiutare a rendere Mac Mouse Fix migliore! 💙💛❤️