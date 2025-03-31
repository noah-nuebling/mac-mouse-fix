Mac Mouse Fix **2.2.5** presenta miglioramenti al meccanismo di aggiornamento ed è pronto per macOS 15 Sequoia!

### Nuovo framework di aggiornamento Sparkle

Mac Mouse Fix utilizza il framework di aggiornamento [Sparkle](https://sparkle-project.org/) per fornire un'ottima esperienza di aggiornamento.

Con la versione 2.2.5, Mac Mouse Fix passa da Sparkle 1.26.0 all'ultima versione [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), che include correzioni di sicurezza, miglioramenti alla localizzazione e altro ancora.

### Meccanismo di aggiornamento più intelligente

C'è un nuovo meccanismo che decide quale aggiornamento mostrare all'utente. Il comportamento è cambiato nei seguenti modi:

1. Dopo aver saltato un aggiornamento **maggiore** (come da 2.2.5 -> 3.0.0), continuerai a ricevere notifiche per gli aggiornamenti **minori** (come da 2.2.5 -> 2.2.6).
    - Questo ti permette di rimanere facilmente su Mac Mouse Fix 2 continuando a ricevere aggiornamenti, come discusso nell'Issue GitHub [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Invece di mostrare l'aggiornamento all'ultima versione, Mac Mouse Fix mostrerà ora l'aggiornamento alla prima versione dell'ultima versione maggiore.
    - Esempio: Se stai usando MMF 2.2.5 e MMF 3.4.5 è l'ultima versione, l'app mostrerà ora la prima versione di MMF 3 (3.0.0), invece dell'ultima versione (3.4.5). In questo modo, tutti gli utenti di MMF 2.2.5 vedranno il changelog di MMF 3.0.0 prima di passare a MMF 3.
    - Discussione:
        - La motivazione principale è che, all'inizio di quest'anno, molti utenti di MMF 2 hanno aggiornato direttamente da MMF 2 a MMF 3.0.1 o 3.0.2. Non avendo mai visto il changelog di 3.0.0, hanno perso le informazioni sui cambiamenti di prezzo tra MMF 2 e MMF 3 (MMF 3 non è più completamente gratuito). Quindi quando MMF 3 ha improvvisamente richiesto un pagamento per continuare a utilizzare l'app, alcuni sono rimasti - comprensibilmente - un po' confusi e scontenti.
        - Svantaggio: Se vuoi semplicemente aggiornare all'ultima versione, in alcuni casi dovrai aggiornare due volte. Questo è leggermente inefficiente, ma dovrebbe comunque richiedere solo pochi secondi. E poiché questo rende i cambiamenti tra le versioni maggiori molto più trasparenti, penso sia un compromesso ragionevole.

### Supporto per macOS 15 Sequoia

Mac Mouse Fix 2.2.5 funzionerà perfettamente sul nuovo macOS 15 Sequoia - proprio come la versione 2.2.4.

---

Dai anche un'occhiata alla versione precedente [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Se hai problemi ad abilitare Mac Mouse Fix dopo l'aggiornamento, consulta la [Guida 'Abilitare Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*