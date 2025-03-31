Mac Mouse Fix **3.0.2** porta diversi miglioramenti, tra cui **scorrimento più fluido**, traduzioni migliorate e altro ancora!

### Scorrimento

- Ora puoi interrompere le animazioni di scorrimento facendo un passo nella direzione opposta. Questo ti permette di **'lanciare'** e **'catturare la pagina'** quando usi 'Fluidità: Alta', in modo simile a un Trackpad.
- Mac Mouse Fix ora invia gli eventi di scorrimento all'inizio del ciclo di aggiornamento del display, dando alle app più tempo per elaborare gli eventi e mostrare uno scorrimento fluido. Questo **migliora i frame rate**, specialmente su siti web complessi come YouTube.com.
- Migliorata la reattività dell'impostazione 'Fluidità: Alta', rendendo lo scorrimento più facile da controllare.
- Migliorato il meccanismo introdotto in 3.0.1 dove la velocità dell'animazione diventa più rapida quando muovi più velocemente la rotella di scorrimento usando 'Fluidità: Normale'. In 3.0.2 l'accelerazione dell'animazione dovrebbe apparire più consistente e prevedibile, risultando più piacevole alla vista pur mantenendo un ottimo controllo.
- Risolto un problema dove la velocità di scorrimento era troppo lenta, specialmente usando l'opzione 'Precisione'. Questo problema era stato introdotto in 3.0.1. Grazie a @V-Coba per averlo segnalato in [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- Migliorato il comportamento nel browser Arc quando si usa 'Clicca e Scorri' per 'Ingrandire o Rimpicciolire'.

### Localizzazione

- Aggiornate le traduzioni in 🇻🇳 Vietnamita. Crediti a @nghlt!
- Migliorate alcune traduzioni in 🇩🇪 Tedesco.
- Il testo all'interno di Mac Mouse Fix che non ha una traduzione per la lingua corrente ora mostrerà un valore segnaposto invece di rimanere vuoto. Questo dovrebbe rendere meno confusa la navigazione nell'app quando mancano delle traduzioni.

### Altro

- Mac Mouse Fix ora mostrerà una notifica con un link a [questa guida](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) agli utenti che potrebbero riscontrare un bug in macOS 13 Ventura e versioni successive che può impedire l'attivazione di Mac Mouse Fix.
- Modificate le impostazioni predefinite per i mouse con 3 pulsanti. Le impostazioni predefinite non includono più un'azione 'Clicca e Scorri' per il pulsante della rotella di scorrimento, poiché è piuttosto difficile da eseguire. Invece, le impostazioni predefinite ora includono un'azione 'Tieni Premuto' e 'Doppio Clic'.
- Aggiunto un suggerimento all'icona di Mac Mouse Fix nella scheda Info. Ti spiega come trovare il file di configurazione di Mac Mouse Fix nel Finder.
- Molti miglioramenti e pulizie sotto il cofano.

---

Dai anche un'occhiata alla versione precedente [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).