Mac Mouse Fix **3.0.4 Beta 1** millora la privadesa, l'eficiència i la fiabilitat.\
Introdueix un nou sistema de llicències sense connexió i corregeix diversos errors importants.

### Millora de la privadesa i l'eficiència

- Introdueix un nou sistema de validació de llicències sense connexió que minimitza les connexions a Internet.
- L'aplicació ara només es connecta a Internet quan és absolutament necessari, protegint la teva privadesa i reduint l'ús de recursos.
- L'aplicació funciona completament sense connexió durant l'ús normal quan té llicència.

<details>
<summary><b>Informació detallada sobre privadesa</b></summary>
Les versions anteriors validaven les llicències en línia a cada inici, permetent potencialment que els registres de connexió fossin emmagatzemats per servidors de tercers (GitHub i Gumroad). El nou sistema elimina les connexions innecessàries – després de l'activació inicial de la llicència, només es connecta a Internet si les dades locals de la llicència estan corrompudes.
<br><br>
Tot i que jo personalment mai vaig registrar el comportament dels usuaris, el sistema anterior teòricament permetia que els servidors de tercers registressin adreces IP i temps de connexió. Gumroad també podia registrar la teva clau de llicència i potencialment correlacionar-la amb qualsevol informació personal que haguessin registrat sobre tu quan vas comprar Mac Mouse Fix.
<br><br>
No vaig considerar aquests subtils problemes de privadesa quan vaig construir el sistema de llicències original, però ara, Mac Mouse Fix és tan privat i lliure d'Internet com és possible!
<br><br>
Vegeu també la <a href=https://gumroad.com/privacy>política de privadesa de Gumroad</a> i aquest <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>comentari meu a GitHub</a>.

</details>

### Correccions d'errors

- S'ha corregit un error on macOS de vegades es quedava penjat quan s'utilitzava 'Clic i arrossega' per a 'Spaces i Mission Control'.
- S'ha corregit un error on les dreceres de teclat a Configuració del Sistema de vegades s'eliminaven quan s'utilitzava una acció de 'Clic' definida a Mac Mouse Fix com ara 'Mission Control'.
- S'ha corregit [un error](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) on l'aplicació de vegades deixava de funcionar i mostrava una notificació que els 'Dies gratuïts s'han acabat' als usuaris que ja havien comprat l'aplicació.
    - Si has experimentat aquest error, em disculpo sincerament per les molèsties. Pots sol·licitar un [reemborsament aquí](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).

### Millores tècniques

- S'ha implementat un nou sistema 'MFDataClass' que permet una modelització de dades més neta i arxius de configuració llegibles per humans.
- S'ha construït suport per afegir plataformes de pagament diferents de Gumroad. Així que en el futur, podria haver-hi compres localitzades, i l'aplicació es podria vendre a diferents països!

### S'ha eliminat el suport (no oficial) per a macOS 10.14 Mojave

Mac Mouse Fix 3 oficialment suporta macOS 11 Big Sur i posteriors. No obstant això, per als usuaris disposats a acceptar alguns errors i problemes gràfics, Mac Mouse Fix 3.0.3 i anteriors encara es podien utilitzar a macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 elimina aquest suport i **ara requereix macOS 10.15 Catalina**.\
Em disculpo per qualsevol inconvenient causat per això. Aquest canvi em va permetre implementar el sistema de llicències millorat utilitzant funcions modernes de Swift. Els usuaris de Mojave poden continuar utilitzant Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) o la [darrera versió de Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Espero que això sigui una bona solució per a tothom.

*Editat amb l'excel·lent assistència de Claude.*

---

També consulteu la versió anterior [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).