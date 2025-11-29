Mac Mouse Fix **3.0.4** millora la privadesa, l'eficiència i la fiabilitat.\
Introdueix un nou sistema de llicències fora de línia i corregeix diversos errors importants.

### Privadesa i eficiència millorades

La versió 3.0.4 introdueix un nou sistema de validació de llicències fora de línia que minimitza les connexions a internet tant com sigui possible.\
Això millora la privadesa i estalvia recursos del sistema del teu ordinador.\
Quan està llicenciada, l'aplicació ara funciona 100% fora de línia!

<details>
<summary><b>Fes clic aquí per a més detalls</b></summary>
Les versions anteriors validaven les llicències en línia a cada inici, permetent potencialment que els registres de connexió fossin emmagatzemats per servidors de tercers (GitHub i Gumroad). El nou sistema elimina les connexions innecessàries: després de l'activació inicial de la llicència, només es connecta a internet si les dades locals de la llicència estan corrompudes.
<br><br>
Tot i que jo personalment mai he registrat cap comportament d'usuari, el sistema anterior permetia teòricament que servidors de tercers registressin adreces IP i horaris de connexió. Gumroad també podia registrar la teva clau de llicència i potencialment correlacionar-la amb qualsevol informació personal que haguessin registrat sobre tu quan vas comprar Mac Mouse Fix.
<br><br>
No vaig considerar aquests problemes subtils de privadesa quan vaig construir el sistema de llicències original, però ara Mac Mouse Fix és tan privat i lliure d'internet com sigui possible!
<br><br>
També pots consultar la <a href=https://gumroad.com/privacy>política de privadesa de Gumroad</a> i aquest <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>comentari de GitHub</a> meu.

</details>

### Correccions d'errors

- S'ha corregit un error on macOS de vegades es quedava bloquejat en utilitzar 'Clic i arrossegar' per a 'Espais i Mission Control'.
- S'ha corregit un error on les dreceres de teclat a Configuració del sistema de vegades s'esboraven en utilitzar accions de 'Clic' de Mac Mouse Fix com ara 'Mission Control'.
- S'ha corregit [un error](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) on l'aplicació de vegades deixava de funcionar i mostrava una notificació que els 'Dies gratuïts s'han acabat' a usuaris que ja havien comprat l'aplicació.
    - Si has experimentat aquest error, em disculpo sincerament per les molèsties. Pots sol·licitar un [reemborsament aquí](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- S'ha millorat la manera com l'aplicació recupera la seva finestra principal, cosa que pot haver corregit un error on la pantalla 'Activar llicència' de vegades no apareixia.

### Millores d'usabilitat

- S'ha fet impossible introduir espais i salts de línia al camp de text de la pantalla 'Activar llicència'.
    - Això era un punt de confusió comú, perquè és molt fàcil seleccionar accidentalment un salt de línia ocult en copiar la teva clau de llicència dels correus de Gumroad.
- Aquestes notes d'actualització es tradueixen automàticament per a usuaris no anglesos (amb tecnologia de Claude). Espero que sigui útil! Si trobes algun problema, fes-m'ho saber. Això és un primer tast d'un nou sistema de traducció que he estat desenvolupant durant l'últim any.

### Suport eliminat (no oficial) per a macOS 10.14 Mojave

Mac Mouse Fix 3 oficialment és compatible amb macOS 11 Big Sur i versions posteriors. No obstant això, per a usuaris disposats a acceptar alguns errors i problemes gràfics, Mac Mouse Fix 3.0.3 i versions anteriors encara es podien utilitzar a macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 elimina aquest suport i **ara requereix macOS 10.15 Catalina**.\
Em disculpo per qualsevol inconvenient causat per això. Aquest canvi m'ha permès implementar el sistema de llicències millorat utilitzant funcions modernes de Swift. Els usuaris de Mojave poden continuar utilitzant Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) o la [última versió de Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Espero que sigui una bona solució per a tothom.

### Millores internes

- S'ha implementat un nou sistema 'MFDataClass' que permet un modelatge de dades més potent mantenint el fitxer de configuració de Mac Mouse Fix llegible i editable per humans.
- S'ha construït suport per afegir plataformes de pagament diferents de Gumroad. Així que en el futur, podria haver-hi pagaments localitzats i l'aplicació es podria vendre a diferents països.
- S'ha millorat el registre, cosa que em permet crear "Versions de depuració" més efectives per a usuaris que experimenten errors difícils de reproduir.
- Moltes altres petites millores i treballs de neteja.

*Editat amb l'excel·lent assistència de Claude.*

---

També pots consultar la versió anterior [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).