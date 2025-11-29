Mac Mouse Fix **3.0.4** migliora privacy, efficienza e affidabilità.\
Introduce un nuovo sistema di licenze offline e corregge diversi bug importanti.

### Privacy ed Efficienza Migliorate

La versione 3.0.4 introduce un nuovo sistema di validazione delle licenze offline che riduce al minimo le connessioni internet.\
Questo migliora la privacy e risparmia le risorse di sistema del tuo computer.\
Quando è attivata la licenza, l'app ora funziona al 100% offline!

<details>
<summary><b>Clicca qui per maggiori dettagli</b></summary>
Le versioni precedenti validavano le licenze online ad ogni avvio, permettendo potenzialmente la memorizzazione dei log di connessione da parte di server di terze parti (GitHub e Gumroad). Il nuovo sistema elimina le connessioni non necessarie – dopo l'attivazione iniziale della licenza, si connette a internet solo se i dati locali della licenza sono corrotti.
<br><br>
Sebbene nessun comportamento degli utenti sia mai stato registrato da me personalmente, il sistema precedente permetteva teoricamente ai server di terze parti di registrare indirizzi IP e orari di connessione. Gumroad poteva anche registrare la tua chiave di licenza e potenzialmente correlarla a qualsiasi informazione personale registrata su di te al momento dell'acquisto di Mac Mouse Fix.
<br><br>
Non avevo considerato questi sottili problemi di privacy quando ho costruito il sistema di licenze originale, ma ora Mac Mouse Fix è il più privato e indipendente da internet possibile!
<br><br>
Vedi anche la <a href=https://gumroad.com/privacy>politica sulla privacy di Gumroad</a> e questo mio <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>commento su GitHub</a>.

</details>

### Correzioni di Bug

- Corretto un bug per cui macOS a volte si bloccava quando si usava 'Clicca e Trascina' per 'Spaces e Mission Control'.
- Corretto un bug per cui le scorciatoie da tastiera nelle Impostazioni di Sistema venivano a volte eliminate quando si usavano azioni 'Clic' di Mac Mouse Fix come 'Mission Control'.
- Corretto [un bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) per cui l'app a volte smetteva di funzionare e mostrava una notifica che i 'Giorni gratuiti sono finiti' agli utenti che avevano già acquistato l'app.
    - Se hai riscontrato questo bug, mi scuso sinceramente per l'inconveniente. Puoi richiedere un [rimborso qui](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Migliorato il modo in cui l'applicazione recupera la sua finestra principale, che potrebbe aver corretto un bug per cui la schermata 'Attiva Licenza' a volte non appariva.

### Miglioramenti di Usabilità

- Reso impossibile inserire spazi e interruzioni di riga nel campo di testo della schermata 'Attiva Licenza'.
    - Questo era un punto di confusione comune, perché è molto facile selezionare accidentalmente un'interruzione di riga nascosta quando si copia la chiave di licenza dalle email di Gumroad.
- Queste note di aggiornamento sono tradotte automaticamente per gli utenti non anglofoni (Powered by Claude). Spero sia utile! Se riscontri problemi, fammelo sapere. Questa è una prima anteprima di un nuovo sistema di traduzione che sto sviluppando da un anno.

### Supporto (Non Ufficiale) per macOS 10.14 Mojave Rimosso

Mac Mouse Fix 3 supporta ufficialmente macOS 11 Big Sur e versioni successive. Tuttavia, per gli utenti disposti ad accettare alcuni problemi grafici, Mac Mouse Fix 3.0.3 e versioni precedenti potevano ancora essere usati su macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 rimuove quel supporto e **ora richiede macOS 10.15 Catalina**. \
Mi scuso per qualsiasi inconveniente causato da questo cambiamento. Questo ha permesso di implementare il sistema di licenze migliorato usando funzionalità moderne di Swift. Gli utenti di Mojave possono continuare a usare Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) o l'[ultima versione di Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Spero sia una buona soluzione per tutti.

### Miglioramenti Interni

- Implementato un nuovo sistema 'MFDataClass' che permette una modellazione dei dati più potente mantenendo il file di configurazione di Mac Mouse Fix leggibile e modificabile dall'utente.
- Costruito il supporto per aggiungere piattaforme di pagamento diverse da Gumroad. Quindi in futuro potrebbero esserci checkout localizzati e l'app potrebbe essere venduta in diversi paesi.
- Migliorato il logging che mi permette di creare "Debug Build" più efficaci per gli utenti che riscontrano bug difficili da riprodurre.
- Molti altri piccoli miglioramenti e lavori di pulizia.

*Modificato con l'eccellente assistenza di Claude.*

---

Dai un'occhiata anche alla versione precedente [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).