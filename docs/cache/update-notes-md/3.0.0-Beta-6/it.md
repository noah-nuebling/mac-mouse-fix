Dai anche un'occhiata alle **interessanti novità** introdotte in [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

**3.0.0 Beta 6** porta ottimizzazioni profonde e rifinitura, una revisione delle impostazioni di scorrimento, traduzioni in cinese e altro ancora!

Ecco tutte le novità:

## 1. Ottimizzazioni Profonde

Per questa Beta, ho lavorato molto per ottenere il massimo delle prestazioni da Mac Mouse Fix. E ora sono felice di annunciare che, quando clicchi un pulsante del mouse nella Beta 6, è **2 volte** più veloce rispetto alla beta precedente! E lo scorrimento è addirittura **4 volte** più veloce!

Con la Beta 6, MMF disattiverà intelligentemente alcune sue parti per risparmiare il più possibile CPU e batteria.

Per esempio, quando stai usando un mouse con 3 pulsanti ma hai impostato azioni solo per pulsanti non presenti sul tuo mouse come i pulsanti 4 e 5, Mac Mouse Fix smetterà completamente di ascoltare l'input dei pulsanti dal tuo mouse. Significa 0% di utilizzo della CPU quando clicchi un pulsante sul tuo mouse! Oppure quando le impostazioni di scorrimento in MMF corrispondono a quelle di sistema, Mac Mouse Fix smetterà completamente di ascoltare l'input dalla rotella di scorrimento. Significa 0% di utilizzo della CPU quando scorri! Ma se imposti la funzione Command (⌘)-Scroll per lo zoom, Mac Mouse Fix inizierà ad ascoltare l'input della rotella di scorrimento - ma solo mentre tieni premuto il tasto Command (⌘). E così via.
Quindi è davvero intelligente e userà la CPU solo quando necessario!

Questo significa che MMF non è solo il driver per mouse più potente, facile da usare e rifinito per Mac, ma è anche uno dei più ottimizzati ed efficienti, se non il più ottimizzato ed efficiente!

## 2. Dimensioni dell'App Ridotte

A 16 MB, la Beta 6 è circa 2 volte più piccola della Beta 5!

Questo è un effetto collaterale dell'abbandono del supporto per le versioni macOS più vecchie.

## 3. Supporto Abbandonato per Versioni macOS Più Vecchie

Ho cercato duramente di far funzionare MMF 3 correttamente su versioni macOS precedenti a macOS 11 Big Sur. Ma la quantità di lavoro necessaria per renderlo rifinito si è rivelata eccessiva, quindi ho dovuto rinunciare.

D'ora in poi, la versione ufficialmente supportata più vecchia sarà macOS 11 Big Sur.

L'app si aprirà ancora su versioni precedenti ma ci saranno problemi visivi e forse altri problemi. L'app non si aprirà più su versioni macOS precedenti alla 10.14.4. Questo è ciò che ci permette di ridurre le dimensioni dell'app del 50% poiché 10.14.4 è la prima versione macOS che include le librerie Swift moderne (Vedi "Swift ABI Stability"), il che significa che queste librerie Swift non devono più essere contenute nell'app.

## 4. Miglioramenti allo Scorrimento

La Beta 6 presenta molti miglioramenti alla configurazione e all'interfaccia utente dei nuovi sistemi di scorrimento introdotti in MMF 3.

### Interfaccia Utente

- Notevolmente semplificato e accorciato il testo dell'interfaccia utente nella scheda Scorrimento. La maggior parte delle menzioni della parola "Scorrimento" sono state rimosse poiché sono implicite dal contesto.
- Riviste le impostazioni della fluidità di scorrimento per renderle molto più chiare e permettere alcune opzioni aggiuntive. Ora puoi scegliere tra una "Fluidità" "Disattivata", "Regolare" o "Alta", sostituendo il vecchio interruttore "con Inerzia". Penso che questo sia molto più chiaro e ha fatto spazio nell'interfaccia utente per la nuova opzione "Simulazione Trackpad".
- Disattivare la nuova opzione "Simulazione Trackpad" disabilita l'effetto elastico durante lo scorrimento, impedisce anche lo scorrimento tra le pagine in Safari e altre app, e altro ancora. Molte persone sono state infastidite da questo, specialmente quelle con rotelle di scorrimento a rotazione libera come quelle trovate su alcuni Mouse Logitech come l'MX Master, ma altri lo apprezzano, quindi ho deciso di renderlo un'opzione. Spero che la presentazione della funzione sia chiara. Se hai suggerimenti al riguardo, fammelo sapere.
- Cambiato l'opzione "Direzione Naturale di Scorrimento" in "Inverti Direzione di Scorrimento". Questo significa che l'impostazione ora inverte la direzione di scorrimento di sistema e non è più indipendente dalla direzione di scorrimento di sistema. Mentre questo è probabilmente una esperienza utente leggermente peggiore, questo nuovo modo di fare le cose ci permette di implementare alcune ottimizzazioni e rende più trasparente per l'utente come disattivare completamente Mac Mouse Fix per lo scorrimento.
- Migliorato il modo in cui le impostazioni di scorrimento interagiscono con lo scorrimento modificato in molti casi limite diversi. Ad esempio, l'opzione "Precisione" non si applicherà più al "Clicca e Scorri" per l'azione "Desktop e Launchpad" poiché qui è un ostacolo invece di essere d'aiuto.
- Migliorata la velocità di scorrimento quando si usa "Clicca e Scorri" per "Desktop e Launchpad" o "Zoom Avanti o Indietro" e altre funzioni.
- Rimosso il link non funzionante alle impostazioni di velocità di scorrimento di sistema nella scheda scorrimento che era presente su versioni macOS precedenti a macOS 13.0 Ventura. Non sono riuscito a trovare un modo per far funzionare il link e non è terribilmente importante.

### Sensazione di Scorrimento

- Migliorata la curva di animazione per "Fluidità Regolare" (precedentemente accessibile disattivando "con Inerzia"). Questo rende le cose più fluide e reattive.
- Migliorata la sensazione di tutte le impostazioni di velocità di scorrimento. La velocità "Media" e la velocità "Veloce" sono più veloci. C'è più separazione tra le velocità "Bassa" "Media" e "Alta". L'accelerazione mentre muovi la rotella più velocemente si sente più naturale e comoda quando usi l'opzione "Precisione".
- Il modo in cui la velocità di scorrimento aumenta mentre continui a scorrere in una direzione si sentirà più naturale e graduale. Sto usando nuove curve matematiche per modellare l'accelerazione. L'aumento di velocità sarà anche più difficile da attivare accidentalmente.
- Non aumenta più la velocità di scorrimento quando continui a scorrere in una direzione mentre usi la velocità di scorrimento "macOS".
- Limitato il tempo di animazione dello scorrimento a un massimo. Se l'animazione di scorrimento dovesse naturalmente richiedere più tempo verrà accelerata per rimanere sotto il tempo massimo. In questo modo, scorrere fino al bordo della pagina con una rotella a rotazione libera non farà spostare il contenuto della pagina fuori schermo per così tanto tempo. Questo non dovrebbe influenzare lo scorrimento normale con una rotella non a rotazione libera.
- Migliorati alcuni comportamenti relativi all'effetto elastico quando si scorre fino al bordo della pagina in Safari e altre app.
- Risolto un problema dove "Clicca e Scorri" e altre funzioni relative allo scorrimento non funzionavano correttamente dopo l'aggiornamento da una versione molto vecchia del pannello preferenze di Mac Mouse Fix.
- Risolto un problema dove gli scorrimenti di un singolo pixel venivano inviati con ritardo quando si usa la velocità di scorrimento "macOS" insieme allo scorrimento fluido.
- Risolto un bug dove lo scorrimento era ancora molto veloce dopo aver rilasciato il modificatore di Scorrimento Veloce. Altri miglioramenti su come la velocità di scorrimento viene trasferita da precedenti movimenti di scorrimento.
- Migliorato il modo in cui la velocità di scorrimento aumenta con dimensioni del display maggiori.

## 5. Notarizzazione

A partire da 3.0.0 Beta 6, Mac Mouse Fix sarà "Notarizzato". Questo significa niente più messaggi su Mac Mouse Fix come potenzialmente "Software Dannoso" quando si apre l'app per la prima volta.

Notarizzare la tua app costa $100 all'anno. Sono sempre stato contrario a questo, poiché sembrava ostile verso il software gratuito e open source come Mac Mouse Fix, e sembrava anche un passo pericoloso verso il controllo e il blocco del Mac da parte di Apple come fanno con iOS. Ma la mancanza di Notarizzazione ha portato a problemi piuttosto gravi, incluse [diverse situazioni](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) dove nessuno poteva usare l'app finché non rilasciavo una nuova versione. Dato che Mac Mouse Fix sarà monetizzato ora, ho pensato che fosse finalmente appropriato Notarizzare l'app per un'esperienza utente più facile e stabile.

## 6. Traduzioni in Cinese

Mac Mouse Fix è ora disponibile in cinese!
Più specificamente, è disponibile in:

- Cinese, Tradizionale
- Cinese, Semplificato
- Cinese (Hong Kong)

Un enorme grazie a @groverlynn per aver fornito tutte queste traduzioni e per averle aggiornate durante le beta e per aver comunicato con me. Vedi la sua pull request qui: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Tutto il Resto

Oltre ai cambiamenti elencati sopra, la Beta 6 presenta anche molti miglioramenti minori.

- Rimosse diverse opzioni dalle Azioni "Clicca", "Clicca e Tieni Premuto" e "Clicca e Scorri" perché pensavo fossero ridondanti dato che la stessa funzionalità può essere ottenuta in altro modo e dato che questo pulisce molto i menu. Riporterò queste opzioni se le persone si lamentano. Quindi se ti mancano queste opzioni - per favore lamentati.
- La direzione di Clicca e Trascina ora corrisponderà alla direzione del gesto del trackpad anche quando "Scorrimento naturale" è disattivato in Impostazioni di Sistema > Trackpad. Prima, Clicca e Trascina si comportava sempre come scorrere sul trackpad con "Scorrimento naturale" *attivato*.
- Risolto un problema dove i cursori scomparivano e poi riapparivano da qualche altra parte quando si usa un'Azione "Clicca e Trascina" durante una registrazione dello schermo o quando si usa il software DisplayLink.
- Sistemato il centraggio del "+" nel campo "+" nella scheda Pulsanti
- Diversi miglioramenti visivi alla scheda pulsanti. La palette di colori del campo "+" e della Tabella Azioni è stata rivista per apparire corretta quando si usa l'opzione "Consenti colorazione dello sfondo nelle finestre" di macOS. I bordi della Tabella Azioni ora hanno un colore trasparente che appare più dinamico e si adatta al suo ambiente.
- Fatto in modo che quando aggiungi molte azioni alla tabella azioni e la finestra di Mac Mouse Fix cresce, crescerà esattamente grande quanto lo schermo (o quanto lo schermo meno il dock se non hai abilitato il nascondimento del dock) e poi si fermerà. Quando aggiungi ancora più azioni, la tabella azioni inizierà a scorrere.
- Questa Beta ora supporta un nuovo checkout dove puoi comprare una licenza in dollari USA come pubblicizzato. Prima potevi comprare una licenza solo in Euro. Le vecchie licenze in Euro saranno ovviamente ancora supportate.
- Risolto un problema dove lo scorrimento con inerzia a volte non veniva avviato quando si usa la funzione "Scorri e Naviga".
- Quando la finestra di Mac Mouse Fix si ridimensiona durante un cambio di scheda ora si riposizionerà in modo da non sovrapporsi con il Dock
- Risolto lo sfarfallio su alcuni elementi dell'interfaccia utente quando si passa dalla scheda Pulsanti a un'altra scheda
- Migliorato l'aspetto dell'animazione che il campo "+" riproduce dopo aver registrato un input. Specialmente su versioni macOS precedenti a Ventura, dove l'ombra del campo "+" appariva difettosa durante l'animazione.
- Disabilitate le notifiche che elencano diversi pulsanti che sono stati catturati/non sono più catturati da Mac Mouse Fix che apparivano quando si avviava l'app per la prima volta o quando si caricava un preset. Ho pensato che questi messaggi fossero distraenti e leggermente travolgenti e non molto utili in quei contesti.
- Rivista la Schermata di Concessione Accessibilità. Ora mostrerà informazioni sul perché Mac Mouse Fix ha bisogno dell'Accesso Accessibilità direttamente invece di linkare al sito web ed è un po' più chiara e ha un layout più piacevole visivamente.
- Aggiornato il link dei Riconoscimenti nella scheda Info.
- Migliorati i messaggi di errore quando Mac Mouse Fix non può essere abilitato perché c'è un'altra versione presente nel sistema. Il messaggio ora verrà mostrato in una finestra di avviso fluttuante che rimane sempre in primo piano rispetto alle altre finestre finché non viene chiusa invece di una Notifica Toast che scompare quando si clicca da qualche parte. Questo dovrebbe rendere più facile seguire i passi della soluzione suggerita.
- Risolti alcuni problemi con il rendering markdown su versioni macOS precedenti a Ventura. MMF ora userà una soluzione di rendering markdown personalizzata per tutte le versioni macOS, inclusa Ventura. Prima stavamo usando un'API di sistema introdotta in Ventura ma questo portava a inconsistenze. Markdown è usato per aggiungere link ed enfasi al testo in tutta l'interfaccia utente.
- Rifinite le interazioni relative all'abilitazione dell'accesso accessibilità.
- Risolto un problema dove la finestra dell'app a volte si apriva senza mostrare alcun contenuto finché non passavi a una delle schede.
- Risolto un problema con il campo "+" dove a volte non potevi aggiungere una nuova azione anche se mostrava un effetto hover che indicava che potevi inserire un'azione.
- Risolto un deadlock e diversi altri piccoli problemi che a volte accadevano quando si muoveva il puntatore del mouse dentro il campo "+".
- Risolto un problema dove un popover che appare nella scheda Pulsanti quando il tuo mouse non sembra adattarsi alle impostazioni dei pulsanti correnti a volte aveva tutto il testo in grassetto.
- Aggiornati tutti i riferimenti alla vecchia licenza MIT alla nuova licenza MMF. I nuovi file creati per il progetto ora conterranno un'intestazione autogenerata che menziona la licenza MMF.
- Fatto in modo che il passaggio alla scheda Pulsanti abiliti MMF per lo Scorrimento. Altrimenti, non potevi registrare gesti Clicca e Scorri.
- Risolti alcuni problemi dove i nomi dei pulsanti non venivano visualizzati correttamente nella Tabella Azioni in alcune situazioni.
- Risolto un bug dove la sezione di prova nella schermata Info appariva difettosa quando si apriva l'app e poi si passava alla scheda prova dopo che la prova era scaduta.
- Risolto un bug dove il link Attiva Licenza nella sezione di prova della scheda Info a volte non reagiva ai clic.
- Risolto un memory leak quando si usa la funzione "Clicca e Trascina" per "Spazi e Mission Control".
- Abilitato runtime Hardened sull'app principale Mac Mouse Fix, migliorando la sicurezza
- Molte pulizie del codice, ristrutturazione del progetto
- Diversi altri crash risolti
- Diversi memory leak risolti
- Vari piccoli aggiustamenti alle stringhe dell'interfaccia utente
- Le rielaborazioni di diversi sistemi interni hanno anche migliorato la robustezza e il comportamento in casi limite

## 8. Come Puoi Aiutare

Puoi aiutare condividendo le tue **idee**, **problemi** e **feedback**!

Il posto migliore per condividere le tue **idee** e **problemi** è l'[Assistente Feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Il posto migliore per dare **feedback** veloce non strutturato è la [Discussione Feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Puoi anche accedere a questi posti dall'interno dell'app nella scheda "**ⓘ Info**".

**Grazie** per aiutare a rendere Mac Mouse Fix il migliore possibile! 🙌:)