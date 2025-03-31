Dai anche un'occhiata ai **miglioramenti interessanti** introdotti in [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6)!


---

**3.0.0 Beta 7** porta diversi piccoli miglioramenti e correzioni di bug.

Ecco tutte le novità:

**Miglioramenti**

- Aggiunte **traduzioni in coreano**. Un grande ringraziamento a @jeongtae! (Trovalo su [GitHub](https://github.com/jeongtae))
- Reso lo **scorrimento** con l'opzione 'Fluidità: Alta' **ancora più fluido**, cambiando la velocità solo gradualmente, invece di avere improvvisi salti nella velocità di scorrimento mentre muovi la rotella. Questo dovrebbe rendere lo scorrimento un po' più fluido e più facile da seguire con gli occhi senza rendere le cose meno reattive. Lo scorrimento con 'Fluidità: Alta' usa circa il 30% in più di CPU, sul mio computer è passato dall'1,2% all'1,6% di utilizzo CPU durante lo scorrimento continuo. Quindi lo scorrimento rimane altamente efficiente e spero che questo non faccia differenza per nessuno. Un grande ringraziamento a [MOS](https://mos.caldis.me/), che ha ispirato questa funzionalità e il cui 'Scroll Monitor' ho usato per implementarla.
- Mac Mouse Fix ora **gestisce gli input dei pulsanti da tutte le fonti**. Prima, Mac Mouse Fix gestiva solo gli input dai mouse che riconosceva. Penso che questo possa aiutare la compatibilità con certi mouse in casi particolari, come quando si usa un Hackintosh, ma porterà anche Mac Mouse Fix a rilevare input artificiali generati da altre app, che potrebbero causare problemi in altri casi particolari. Fatemi sapere se questo causa problemi, e li affronterò nei prossimi aggiornamenti.
- Raffinata la sensazione e la rifinitura dei gesti 'Clicca e Scorri' per 'Desktop e Launchpad' e 'Clicca e Scorri' per 'Muoversi tra gli Spazi'.
- Ora si tiene conto della densità di informazioni di una lingua quando si calcola il **tempo di visualizzazione delle notifiche**. Prima, le notifiche rimanevano visibili per un tempo molto breve nelle lingue con alta densità di informazioni come il cinese o il coreano.
- Abilitati **diversi gesti** per muoversi tra gli **Spazi**, aprire **Mission Control** o aprire **App Exposé**. Nella Beta 6, avevo fatto in modo che queste azioni fossero disponibili solo attraverso il gesto 'Clicca e Trascina' - come esperimento per vedere quante persone tenessero davvero a poter accedere a queste azioni in altri modi. Sembra che alcuni ci tengano, quindi ora ho reso di nuovo possibile accedere a queste azioni attraverso un semplice 'Clic' di un pulsante o attraverso 'Clicca e Scorri'.
- Resa possibile la **Rotazione** attraverso un gesto **Clicca e Scorri**.
- **Migliorato** il funzionamento dell'opzione **Simulazione Trackpad** in alcuni scenari. Per esempio, quando si scorre orizzontalmente per eliminare un messaggio in Mail, la direzione in cui si muove il messaggio ora è invertita, il che spero risulti un po' più naturale e coerente per la maggior parte delle persone.
- Aggiunta una funzione per **rimappare** il **Clic Primario** o il **Clic Secondario**. Ho implementato questo perché il tasto destro del mio mouse preferito si è rotto. Queste opzioni sono nascoste di default. Puoi vederle tenendo premuto il tasto Opzione mentre selezioni un'azione.
  - Al momento mancano le traduzioni in cinese e coreano, quindi se vuoi contribuire con le traduzioni per queste funzionalità sarebbe molto apprezzato!

**Correzioni di Bug**

- Risolto un bug dove la **direzione di 'Clicca e Trascina'** per 'Mission Control e Spazi' era **invertita** per le persone che non hanno mai attivato l'opzione 'Scorrimento naturale' nelle Impostazioni di Sistema. Ora, la direzione dei gesti 'Clicca e Trascina' in Mac Mouse Fix dovrebbe sempre corrispondere alla direzione dei gesti sul tuo Trackpad o Magic Mouse. Se desideri un'opzione separata per invertire la direzione di 'Clicca e Trascina', invece di farla seguire le Impostazioni di Sistema, fammelo sapere.
- Risolto un bug dove i **giorni gratuiti** **aumentavano troppo velocemente** per alcuni utenti. Se sei stato colpito da questo problema, fammelo sapere e vedrò cosa posso fare.
- Risolto un problema in macOS Sonoma dove la barra delle schede non si visualizzava correttamente.
- Risolto il tremolio quando si usa la velocità di scorrimento 'macOS' mentre si usa 'Clicca e Scorri' per aprire Launchpad.
- Risolto un crash dove l'app 'Mac Mouse Fix Helper' (che gira in background quando Mac Mouse Fix è attivo) si bloccava a volte durante la registrazione di una scorciatoia da tastiera.
- Risolto un bug dove Mac Mouse Fix si bloccava quando cercava di rilevare eventi artificiali generati da [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma)
- Risolto un problema dove il nome di alcuni mouse visualizzato nella finestra 'Ripristina Predefiniti...' conteneva il produttore due volte.
- Resa meno probabile la possibilità che 'Clicca e Trascina' per 'Mission Control e Spazi' si blocchi quando il computer è lento.
- Corretto l'uso di 'Force Touch' nelle stringhe dell'interfaccia dove dovrebbe essere 'Force click'.
- Risolto un bug che si verificava con certe configurazioni, dove aprire Launchpad o mostrare il Desktop attraverso 'Clicca e Scorri' non funzionava se rilasciavi il pulsante mentre l'animazione di transizione era ancora in corso.

**Altro**

- Diversi miglioramenti sotto il cofano, miglioramenti della stabilità, pulizia del codice e altro ancora.

## Come Puoi Aiutare

Puoi aiutare condividendo le tue **idee**, **problemi** e **feedback**!

Il posto migliore per condividere le tue **idee** e **problemi** è l'[Assistente Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Il posto migliore per dare **feedback** veloce e non strutturato è la [Discussione Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Puoi accedere a questi luoghi anche dall'interno dell'app nella scheda '**ⓘ Info**'.

**Grazie** per aiutare a rendere Mac Mouse Fix migliore! 😎:)