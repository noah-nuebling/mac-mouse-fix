Mac Mouse Fix **3.0.6** fa que la funció 'Enrere' i 'Endavant' sigui compatible amb més aplicacions.
També soluciona diversos errors i problemes.

### Funció 'Enrere' i 'Endavant' millorada

Les assignacions dels botons del ratolí 'Enrere' i 'Endavant' ara **funcionen en més aplicacions**, incloent:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed i altres editors de codi
- Moltes aplicacions integrades d'Apple com ara Visualització Prèvia, Notes, Configuració del Sistema, App Store i Música
- Adobe Acrobat
- Zotero
- I més!

La implementació està inspirada en l'excel·lent funció 'Universal Back and Forward' de [LinearMouse](https://github.com/linearmouse/linearmouse). Hauria de ser compatible amb totes les aplicacions que LinearMouse suporta. \
A més, és compatible amb algunes aplicacions que normalment requereixen dreceres de teclat per anar enrere i endavant, com ara Configuració del Sistema, App Store, Apple Notes i Adobe Acrobat. Mac Mouse Fix ara detectarà aquestes aplicacions i simularà les dreceres de teclat apropiades.

Totes les aplicacions que s'han [sol·licitat en un GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) haurien de ser compatibles ara! (Gràcies pels comentaris!) \
Si trobes alguna aplicació que encara no funciona, fes-m'ho saber en una [sol·licitud de funció](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Solució de l'error 'El desplaçament deixa de funcionar intermitentment'

Alguns usuaris van experimentar un [problema](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) on **el desplaçament suau deixa de funcionar** aleatòriament.

Tot i que mai he pogut reproduir el problema, he implementat una possible solució:

L'aplicació ara reintentarà diverses vegades quan falli la configuració de la sincronització amb la pantalla. \
Si encara no funciona després de reintentar-ho, l'aplicació:

- Reiniciarà el procés en segon pla 'Mac Mouse Fix Helper', que pot resoldre el problema
- Generarà un informe d'error, que pot ajudar a diagnosticar l'error

Espero que el problema estigui resolt ara! Si no, fes-m'ho saber en un [informe d'error](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) o per [correu electrònic](http://redirect.macmousefix.com/?target=mailto-noah).



### Comportament millorat de la roda de desplaçament de gir lliure

Mac Mouse Fix ja **no accelerarà el desplaçament** quan deixis que la roda de desplaçament giri lliurement al ratolí MX Master. (O qualsevol altre ratolí amb una roda de desplaçament de gir lliure.)

Tot i que aquesta funció d'acceleració del desplaçament és útil en rodes de desplaçament normals, en una roda de desplaçament de gir lliure pot fer que les coses siguin més difícils de controlar.

**Nota:** Mac Mouse Fix actualment no és totalment compatible amb la majoria de ratolins Logitech, incloent l'MX Master. Tinc previst afegir compatibilitat completa, però probablement trigarà una estona. Mentrestant, el millor controlador de tercers amb suport per a Logitech que conec és [SteerMouse](https://plentycom.jp/en/steermouse/).





### Correccions d'errors

- S'ha solucionat un problema on Mac Mouse Fix de vegades reactivava dreceres de teclat que s'havien desactivat prèviament a Configuració del Sistema  
- S'ha solucionat un error en fer clic a 'Activar llicència' 
- S'ha solucionat un error en fer clic a 'Cancel·lar' just després de fer clic a 'Activar llicència' (Gràcies per l'informe, Ali!)
- S'han solucionat errors en intentar utilitzar Mac Mouse Fix quan no hi ha cap pantalla connectada al teu Mac 
- S'ha solucionat una fuita de memòria i alguns altres problemes interns en canviar entre pestanyes a l'aplicació 

### Millores visuals

- S'ha solucionat un problema on la pestanya Quant a de vegades era massa alta, que es va introduir a la versió [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- El text de la notificació 'S'han acabat els dies gratuïts' ja no es talla en xinès
- S'ha solucionat un error visual a l'ombra del camp '+' després de gravar una entrada
- S'ha solucionat un error poc freqüent on el text de marcador de posició a la pantalla 'Introdueix la teva clau de llicència' apareixia descentrat
- S'ha solucionat un problema on alguns símbols mostrats a l'aplicació tenien el color incorrecte després de canviar entre el mode fosc/clar

### Altres millores

- S'han fet algunes animacions, com ara l'animació de canvi de pestanya, lleugerament més eficients  
- S'ha desactivat la compleció de text de la Touch Bar a la pantalla 'Introdueix la teva clau de llicència' 
- Diverses millores internes menors

*Editat amb l'excel·lent assistència de Claude.*

---

També pots consultar la versió anterior [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).