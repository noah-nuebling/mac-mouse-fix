Mac Mouse Fix **2.2.4** è ora notarizzato! Include anche alcune correzioni di bug e altri miglioramenti.

### **Notarizzazione**

Mac Mouse Fix 2.2.4 è ora 'notarizzato' da Apple. Questo significa che non ci saranno più messaggi che indicano Mac Mouse Fix come potenziale 'Software Dannoso' quando si apre l'app per la prima volta.

#### Contesto

La notarizzazione di un'app costa $100 all'anno. Sono sempre stato contrario a questo, poiché sembrava ostile verso il software gratuito e open source come Mac Mouse Fix, e sembrava anche un pericoloso passo verso il controllo e il blocco del Mac da parte di Apple, come fanno con iPhone o iPad. Ma la mancanza di notarizzazione ha portato a diversi problemi, incluse [difficoltà nell'apertura dell'app](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) e persino [diverse situazioni](https://github.com/noah-nuebling/mac-mouse-fix/issues/95) in cui nessuno poteva più utilizzare l'app fino al rilascio di una nuova versione.

Per Mac Mouse Fix 3, ho pensato che fosse finalmente appropriato pagare i $100 annuali per notarizzare l'app, dato che Mac Mouse Fix 3 è monetizzato. ([Scopri di più](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Ora, anche Mac Mouse Fix 2 ottiene la notarizzazione, che dovrebbe portare a un'esperienza utente più facile e stabile.

### **Correzioni di bug**

- Risolto un problema in cui il cursore scompariva e poi riappariva in una posizione diversa quando si utilizzava un'Azione 'Click and Drag' durante una registrazione dello schermo o mentre si utilizzava il software [DisplayLink](https://www.synaptics.com/products/displaylink-graphics).
- Risolto un problema con l'attivazione di Mac Mouse Fix su macOS 10.14 Mojave e possibilmente anche su versioni macOS più vecchie.
- Migliorata la gestione della memoria, potenzialmente risolvendo un crash dell'app 'Mac Mouse Fix Helper' che si verificava quando si scollegava un mouse dal computer. Vedi Discussione [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Altri Miglioramenti**

- La finestra che l'app mostra per informarti che è disponibile una nuova versione di Mac Mouse Fix ora supporta JavaScript. Questo permette alle note di aggiornamento di essere più belle e più facili da leggere. Per esempio, le note di aggiornamento possono ora mostrare [Markdown Alerts](https://github.com/orgs/community/discussions/16925) e altro.
- Rimosso un link alla pagina https://macmousefix.com/about/ dalla schermata "Concedi Accesso Accessibilità a Mac Mouse Fix Helper". Questo perché la pagina About non esiste più ed è stata sostituita per ora dal [README di GitHub](https://github.com/noah-nuebling/mac-mouse-fix).
- Questa versione include ora i file dSYM che possono essere utilizzati da chiunque per decodificare i report di crash di Mac Mouse Fix 2.2.4.
- Alcune pulizie e miglioramenti sotto il cofano.

---

Dai anche un'occhiata alla versione precedente [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).