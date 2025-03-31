Controlla anche **le novità** in [3.0.0 Beta 3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-3)!

---

**3.0.0 Beta 4** introduce una nuova opzione **"Ripristina predefiniti..."** e molti miglioramenti della **qualità della vita** e **correzioni di bug**!

Ecco **tutto** ciò che c'è di **nuovo**:

## 1. Opzione "Ripristina predefiniti..."

Ora c'è un pulsante "**Ripristina predefiniti...**" nella scheda "Pulsanti".
Questo ti permette di sentirti ancora più **a tuo agio** mentre **sperimenti** con le impostazioni.

Ci sono **2 configurazioni predefinite** disponibili:

1. L'impostazione "Predefinita per mouse con **5+ pulsanti**" è super potente e comoda. Ti permette di fare **tutto** quello che fai con un **trackpad**. Tutto usando i 2 **pulsanti laterali** che sono proprio dove riposa il **pollice**! Ma ovviamente è disponibile solo su mouse con 5 o più pulsanti.
2. L'impostazione "Predefinita per mouse con **3 pulsanti**" ti permette comunque di fare le cose **più importanti** che fai con un trackpad - anche su un mouse che ha solo 3 pulsanti.

Mi sono impegnato per rendere questa funzione **intelligente**:

- Quando avvii MMF per la prima volta, **selezionerà automaticamente** il preset che **meglio si adatta al tuo mouse**.
- Quando vai a ripristinare i predefiniti, Mac Mouse Fix ti **mostrerà** quale **modello di mouse** stai usando e il suo **numero di pulsanti**, così potrai facilmente scegliere quale dei due preset usare. Inoltre **pre-selezionerà** il preset che **meglio si adatta al tuo mouse**.
- Quando passi a un **nuovo mouse** che non si adatta alle tue impostazioni attuali, un popup nella scheda Pulsanti ti **ricorderà** come **caricare** le impostazioni raccomandate per il tuo mouse!
- Tutta l'**interfaccia** che circonda questa funzione è molto **semplice**, **bella** e si **anima** in modo piacevole.

Spero che tu trovi questa funzione **utile** e **semplice da usare**! Ma fammi sapere se hai problemi.
C'è qualcosa di **strano** o **poco intuitivo**? I **popup** appaiono **troppo spesso** o in **situazioni inappropriate**? **Fammi sapere** la tua esperienza!

## 2. Mac Mouse Fix temporaneamente gratuito in alcuni paesi

Ci sono alcuni **paesi** dove il **fornitore di pagamenti** di Mac Mouse Fix, Gumroad, **non funziona** attualmente.
Mac Mouse Fix è ora **gratuito** in **questi paesi** fino a quando non potrò fornire un metodo di pagamento alternativo!

Se ti trovi in uno dei paesi gratuiti, le informazioni su questo saranno **visualizzate** nella **scheda Info** e quando **inserisci una chiave di licenza**

Se è **impossibile acquistare** Mac Mouse Fix nel tuo paese, ma non è ancora **gratuito** nel tuo paese - fammelo sapere e renderò Mac Mouse Fix gratuito anche nel tuo paese!

## 3. Un buon momento per iniziare a tradurre!

Con la Beta 4, ho **implementato tutte le modifiche all'interfaccia** che avevo pianificato per Mac Mouse Fix 3. Quindi non mi aspetto che ci siano altri grandi cambiamenti all'interfaccia fino al rilascio di Mac Mouse Fix 3.

Se hai aspettato perché ti aspettavi che l'interfaccia cambiasse ancora, allora **questo è un buon momento** per iniziare a **tradurre** l'app nella tua lingua!

Per **maggiori informazioni** sulla traduzione dell'app vedi **[Note di rilascio di 3.0.0 Beta 1](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-1.1) > 9. Internazionalizzazione**

## 4. Tutto il resto

Oltre ai cambiamenti elencati sopra, la Beta 4 include molte altre piccole **correzioni di bug**, **modifiche** e miglioramenti della **qualità della vita**:

### Interfaccia utente

#### Correzioni di bug

- Risolto bug dove i link dalla scheda Info si aprivano ripetutamente quando si cliccava ovunque nella finestra. Crediti all'utente GitHub [DingoBits](https://github.com/DingoBits) che ha risolto questo!
- Risolto problema con alcuni simboli nell'app che non si visualizzavano correttamente su versioni macOS più vecchie
- Nascoste le barre di scorrimento nella Tabella Azioni. Grazie all'utente GitHub [marianmelinte93](https://github.com/marianmelinte93) che mi ha reso consapevole di questo problema in [questo commento](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366#discussioncomment-3728994)!
- Risolto problema dove il feedback sulle funzionalità riabilitate automaticamente quando apri la rispettiva scheda per quella funzionalità nell'interfaccia (dopo averla disabilitata dalla barra dei menu) non veniva visualizzato su macOS Monterey e versioni precedenti. Grazie ancora a [marianmelinte93](https://github.com/marianmelinte93) per avermi reso consapevole del problema.
- Aggiunta localizzabilità mancante e traduzioni tedesche per l'opzione "Clicca per scorrere per spostarsi tra gli spazi"
- Risolti altri piccoli problemi di localizzabilità
- Aggiunte altre traduzioni tedesche mancanti
- Le notifiche che si visualizzano quando un pulsante viene catturato / non è più catturato ora funzionano correttamente quando alcuni pulsanti sono stati catturati e altri sono stati non catturati contemporaneamente.

#### Miglioramenti

- Rimossa l'opzione "Clicca e scorri per il Selettore app". Era un po' buggy e non credo fosse molto utile.
- Aggiunta l'opzione "Clicca e scorri per ruotare".
- Modificato il layout del menu "Mac Mouse Fix" nella barra dei menu.
- Aggiunto pulsante "Acquista Mac Mouse Fix" al menu "Mac Mouse Fix" nella barra dei menu.
- Aggiunto un testo di suggerimento sotto l'opzione "Mostra nella barra dei menu". L'obiettivo è rendere più facile scoprire che l'elemento della barra dei menu può essere usato per attivare o disattivare rapidamente le funzionalità
- I messaggi "Grazie per aver acquistato Mac Mouse Fix" nella schermata info possono ora essere completamente personalizzati dai localizzatori.
- Migliorati i suggerimenti per i localizzatori
- Migliorati i testi dell'interfaccia relativi alla scadenza della prova
- Migliorati i testi dell'interfaccia nella scheda Info
- Aggiunti evidenziatori in grassetto ad alcuni testi dell'interfaccia per migliorare la leggibilità
- Aggiunto avviso quando si clicca sul link "Mandami una email" nella scheda Info.
- Cambiato l'ordine di ordinamento della Tabella Azioni. Le azioni Clicca e Scorri ora verranno visualizzate prima delle azioni Clicca e Trascina. Mi sembra più naturale perché ora le righe della tabella sono ordinate in base alla potenza dei loro trigger (Clic < Scorrimento < Trascinamento).
- L'app ora aggiornerà il dispositivo attivamente utilizzato quando si interagisce con l'interfaccia. Questo è utile perché alcune parti dell'interfaccia ora si basano sul dispositivo che stai usando. (Vedi la nuova funzione "Ripristina predefiniti...")
- Una notifica che mostra quali pulsanti sono stati catturati / non sono più catturati ora viene visualizzata quando avvii l'app per la prima volta.
- Altri miglioramenti alle notifiche che si visualizzano quando un pulsante è stato catturato / non è più catturato
- Reso impossibile inserire accidentalmente spazi bianchi estranei durante l'attivazione di una chiave di licenza

### Mouse

#### Correzioni di bug

- Migliorata la simulazione dello scorrimento per inviare correttamente "delta a punto fisso". Questo risolve un problema dove la velocità di scorrimento era troppo lenta in alcune app come Safari con lo scorrimento fluido disattivato.
- Risolto problema dove la funzione "Clicca e trascina per Mission Control e Spazi" si bloccava a volte quando il computer era lento
- Risolto un problema dove la CPU veniva sempre utilizzata da Mac Mouse Fix quando si muoveva il mouse dopo aver usato la funzione "Clicca e trascina per scorrere e navigare"

#### Miglioramenti

- Notevolmente migliorata la reattività dello scorrimento per lo zoom nei browser basati su Chromium come Chrome, Brave o Edge

### Sotto il cofano

#### Correzioni di bug

- Risolto un problema dove Mac Mouse Fix non funzionava correttamente dopo averlo spostato in una cartella diversa mentre era abilitato
- Risolti alcuni problemi con l'abilitazione di Mac Mouse Fix mentre un'altra istanza di Mac Mouse Fix era ancora abilitata. (Questo perché Apple mi ha permesso di cambiare l'ID del bundle da "com.nuebling.mac-mouse-fixxx" usato nella Beta 3 tornando all'originale "com.nuebling.mac-mouse-fix". Non so perché.)

#### Miglioramenti

- Questa e le future beta produrranno informazioni di debug più dettagliate
- Pulizia e miglioramenti sotto il cofano. Rimosso vecchio codice pre-10.13. Puliti framework e dipendenze. Il codice sorgente è ora più facile da gestire e più a prova di futuro.