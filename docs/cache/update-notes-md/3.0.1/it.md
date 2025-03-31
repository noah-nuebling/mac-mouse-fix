Mac Mouse Fix **3.0.1** porta diverse correzioni di bug e miglioramenti, insieme a una **nuova lingua**!

### È stato aggiunto il Vietnamita!

Mac Mouse Fix è ora disponibile in 🇻🇳 Vietnamita. Un grande ringraziamento a @nghlt [su GitHub](https://GitHub.com/nghlt)!

### Correzioni di bug

- Mac Mouse Fix ora funziona correttamente con il **Cambio Rapido Utente**!
  - Il Cambio Rapido Utente è quando accedi a un secondo account macOS senza disconnetterti dal primo account.
  - Prima di questo aggiornamento, lo scorrimento smetteva di funzionare dopo un cambio rapido utente. Ora tutto dovrebbe funzionare correttamente.
- Risolto un piccolo bug dove il layout della scheda Pulsanti era troppo largo dopo aver avviato Mac Mouse Fix per la prima volta.
- Migliorato il funzionamento del campo '+' quando si aggiungono più Azioni in rapida successione.
- Risolto un crash oscuro segnalato da @V-Coba nell'Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Altri miglioramenti

- **Lo scorrimento è più reattivo** quando si usa l'impostazione 'Fluidità: Regolare'.
  - La velocità dell'animazione ora diventa più veloce quando muovi la rotella più velocemente. In questo modo, risulta più reattivo quando scorri velocemente pur mantenendo la stessa fluidità quando scorri lentamente.

- Resa l'**accelerazione della velocità di scorrimento** più stabile e prevedibile.
- Implementato un meccanismo per **mantenere le tue impostazioni** quando aggiorni a una nuova versione di Mac Mouse Fix.
  - Prima, Mac Mouse Fix resettava tutte le tue impostazioni dopo l'aggiornamento a una nuova versione, se la struttura delle impostazioni cambiava. Ora, Mac Mouse Fix tenterà di aggiornare la struttura delle tue impostazioni e mantenere le tue preferenze.
  - Per ora, questo funziona solo quando si aggiorna da 3.0.0 a 3.0.1. Se stai aggiornando da una versione precedente alla 3.0.0, o se fai un _downgrade_ dalla 3.0.1 _a_ una versione precedente, le tue impostazioni verranno comunque resettate.
- Il layout della scheda Pulsanti ora adatta meglio la sua larghezza alle diverse lingue.
- Miglioramenti al [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) e altri documenti.
- Migliorati i sistemi di localizzazione. I file di traduzione vengono ora automaticamente puliti e analizzati per potenziali problemi. C'è una nuova [Guida alla Localizzazione](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) che presenta tutti i problemi rilevati automaticamente insieme ad altre informazioni utili e istruzioni per le persone che vogliono aiutare a tradurre Mac Mouse Fix. Rimossa la dipendenza dallo strumento [BartyCrouch](https://github.com/FlineDev/BartyCrouch) che veniva precedentemente utilizzato per ottenere alcune di queste funzionalità.
- Migliorate diverse stringhe dell'interfaccia utente in inglese e tedesco.
- Molti miglioramenti e pulizie sotto il cofano.

---

Dai anche un'occhiata alle note di rilascio di [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - il più grande aggiornamento di Mac Mouse Fix finora!