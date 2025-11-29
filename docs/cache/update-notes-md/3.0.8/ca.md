Mac Mouse Fix **3.0.8** soluciona problemes de la interfície i més.

### **Problemes de la interfície**

- S'ha desactivat el nou disseny a macOS 26 Tahoe. Ara l'aplicació tindrà l'aspecte i funcionarà com ho feia a macOS 15 Sequoia.
    - Ho he fet perquè alguns dels elements de la interfície redissenyats per Apple encara tenen problemes. Per exemple, els botons '-' de la pestanya 'Botons' no sempre es podien clicar.
    - La interfície pot semblar una mica antiquada a macOS 26 Tahoe ara. Però hauria de ser completament funcional i polida com abans.
- S'ha corregit un error on la notificació 'S'han acabat els dies gratuïts' es quedava encallada a la cantonada superior dreta de la pantalla.
    - Gràcies a [Sashpuri](https://github.com/Sashpuri) i altres per informar-ne!

### **Millores de la interfície**

- S'ha desactivat el botó de semàfor verd a la finestra principal de Mac Mouse Fix.
    - El botó no feia res, ja que la finestra no es pot redimensionar manualment.
- S'ha corregit un problema on algunes de les línies horitzontals de la taula de la pestanya 'Botons' eren massa fosques a macOS 26 Tahoe.
- S'ha corregit un error on el missatge "No es pot utilitzar el botó principal del ratolí" de la pestanya 'Botons' de vegades quedava tallat a macOS 26 Tahoe.
- S'ha corregit una errada tipogràfica a la interfície alemanya. Cortesia de l'usuari de GitHub [i-am-the-slime](https://github.com/i-am-the-slime). Gràcies!
- S'ha solucionat un problema on la finestra de MMF de vegades parpellejava breument amb la mida incorrecta en obrir la finestra a macOS 26 Tahoe.

### **Altres canvis**

- S'ha millorat el comportament quan s'intenta activar Mac Mouse Fix mentre hi ha múltiples instàncies de Mac Mouse Fix executant-se a l'ordinador.
    - Mac Mouse Fix ara intentarà desactivar l'altra instància de Mac Mouse Fix amb més diligència.
    - Això pot millorar casos extrems on Mac Mouse Fix no es podia activar.
- Canvis i neteja interns.

---

També pots consultar les novetats de la versió anterior [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).