Mac Mouse Fix **3.0.7** soluciona diversos errors importants.

### Correccions d'errors

- L'aplicació torna a funcionar en **versions antigues de macOS** (macOS 10.15 Catalina i macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 no es podia activar en aquestes versions de macOS perquè la funció millorada de 'Enrere' i 'Endavant' introduïda a Mac Mouse Fix 3.0.6 intentava utilitzar APIs del sistema macOS que no estaven disponibles.
- S'han solucionat problemes amb la funció **'Enrere' i 'Endavant'**
    - La funció millorada de 'Enrere' i 'Endavant' introduïda a Mac Mouse Fix 3.0.6 ara sempre utilitzarà el 'fil principal' per preguntar a macOS quines tecles s'han de simular per anar enrere i endavant a l'aplicació que estàs utilitzant. \
    Això pot prevenir bloquejos i comportaments poc fiables en algunes situacions.
- S'ha intentat solucionar l'error on **la configuració es restablia aleatòriament**  (Consulta aquests [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - He reescrit el codi que carrega l'arxiu de configuració de Mac Mouse Fix perquè sigui més robust. Quan es produïen errors poc freqüents del sistema d'arxius de macOS, el codi antic podia pensar erròniament que l'arxiu de configuració estava corrupte i el restablia als valors per defecte.
- S'han reduït les possibilitats d'un error on **el desplaçament deixa de funcionar**     
     - Aquest error no es pot solucionar completament sense canvis més profunds, que probablement causarien altres problemes. \
      No obstant això, de moment, he reduït la finestra de temps on pot passar un 'bloqueig mutu' al sistema de desplaçament, cosa que almenys hauria de reduir les possibilitats de trobar-se amb aquest error. Això també fa que el desplaçament sigui lleugerament més eficient. 
    - Aquest error té símptomes similars – però crec que una raó subjacent diferent – a l'error 'El desplaçament deixa de funcionar intermitentment' que es va solucionar a l'última versió 3.0.6.
    - (Gràcies a Joonas pel diagnòstic!) 

Gràcies a tothom per informar dels errors! 

---

També consulta la versió anterior [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).