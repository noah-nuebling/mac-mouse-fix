Mac Mouse Fix **3.0.6** rende la funzione 'Indietro' e 'Avanti' compatibile con più app.
Risolve anche diversi bug e problemi.

### Funzione 'Indietro' e 'Avanti' Migliorata

Le mappature dei pulsanti del mouse 'Indietro' e 'Avanti' ora **funzionano in più app**, tra cui:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed e altri editor di codice
- Molte app Apple integrate come Anteprima, Note, Impostazioni di Sistema, App Store e Musica
- Adobe Acrobat
- Zotero
- E altre ancora!

L'implementazione è ispirata all'ottima funzione 'Universal Back and Forward' di [LinearMouse](https://github.com/linearmouse/linearmouse). Dovrebbe supportare tutte le app supportate da LinearMouse. \
Inoltre supporta alcune app che normalmente richiedono scorciatoie da tastiera per andare indietro e avanti, come Impostazioni di Sistema, App Store, Note di Apple e Adobe Acrobat. Mac Mouse Fix ora rileverà queste app e simulerà le scorciatoie da tastiera appropriate.

Ogni app che sia mai stata [richiesta in un GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) dovrebbe essere supportata ora! (Grazie per il feedback!) \
Se trovi app che non funzionano ancora, fammelo sapere in una [richiesta di funzionalità](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Risoluzione del Bug 'Lo Scorrimento Smette di Funzionare Intermittentemente'

Alcuni utenti hanno riscontrato un [problema](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) in cui **lo scorrimento fluido smette di funzionare** in modo casuale.

Anche se non sono mai riuscito a riprodurre il problema, ho implementato una potenziale soluzione:

L'app ora riproverà più volte quando la configurazione della sincronizzazione con il display fallisce. \
Se ancora non funziona dopo i tentativi, l'app:

- Riavvierà il processo in background 'Mac Mouse Fix Helper', che potrebbe risolvere il problema
- Produrrà un report di crash, che potrebbe aiutare a diagnosticare il bug

Spero che il problema sia risolto ora! In caso contrario, fammelo sapere in una [segnalazione di bug](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) o via [email](http://redirect.macmousefix.com/?target=mailto-noah).



### Comportamento Migliorato della Rotellina a Rotazione Libera

Mac Mouse Fix **non accelererà più lo scorrimento** quando lasci girare liberamente la rotellina sul mouse MX Master. (O qualsiasi altro mouse con rotellina a rotazione libera.)

Sebbene questa funzione di 'accelerazione dello scorrimento' sia utile sulle rotelle di scorrimento normali, su una rotellina a rotazione libera può rendere le cose più difficili da controllare.

**Nota:** Mac Mouse Fix attualmente non è completamente compatibile con la maggior parte dei mouse Logitech, incluso l'MX Master. Ho in programma di aggiungere il supporto completo, ma probabilmente ci vorrà un po' di tempo. Nel frattempo, il miglior driver di terze parti con supporto Logitech che conosco è [SteerMouse](https://plentycom.jp/en/steermouse/).





### Correzioni di Bug

- Risolto un problema per cui Mac Mouse Fix a volte riabilitava scorciatoie da tastiera precedentemente disabilitate nelle Impostazioni di Sistema  
- Risolto un crash quando si cliccava su 'Attiva Licenza' 
- Risolto un crash quando si cliccava su 'Annulla' subito dopo aver cliccato su 'Attiva Licenza' (Grazie per la segnalazione, Ali!)
- Risolti crash quando si tentava di usare Mac Mouse Fix senza display collegato al Mac 
- Risolto un memory leak e altri problemi interni quando si cambiava tra le schede nell'app 

### Miglioramenti Visivi

- Risolto un problema per cui la scheda Informazioni era a volte troppo alta, introdotto nella [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Il testo sulla notifica 'I giorni gratuiti sono finiti' non è più tagliato in cinese
- Risolto un glitch visivo sull'ombra del campo '+' dopo la registrazione di un input
- Risolto un raro glitch in cui il testo segnaposto nella schermata 'Inserisci la Tua Chiave di Licenza' appariva decentrato
- Risolto un problema per cui alcuni simboli visualizzati nell'app avevano il colore sbagliato dopo il passaggio tra modalità scura/chiara

### Altri Miglioramenti

- Rese alcune animazioni, come l'animazione di cambio scheda, leggermente più efficienti  
- Disabilitato il completamento automatico della Touch Bar nella schermata 'Inserisci la Tua Chiave di Licenza' 
- Vari miglioramenti interni minori

*Modificato con l'eccellente assistenza di Claude.*

---

Dai un'occhiata anche alla versione precedente [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).