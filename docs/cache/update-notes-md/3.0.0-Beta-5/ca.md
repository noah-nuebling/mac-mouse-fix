També doneu un cop d'ull als **canvis interessants** introduïts a [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

**3.0.0 Beta 5** restaura la **compatibilitat** amb alguns **ratolins** a macOS 13 Ventura i **arregla el desplaçament** en moltes aplicacions.
També inclou diverses correccions menors i millores en la qualitat de vida.

Aquí hi ha **tot el que és nou**:

### Ratolí

- S'ha arreglat el desplaçament a Terminal i altres aplicacions! Vegeu el problema de GitHub [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- S'ha corregit la incompatibilitat amb alguns ratolins a macOS 13 Ventura deixant d'utilitzar les APIs poc fiables d'Apple en favor de solucions de baix nivell. Espero que això no introdueixi nous problemes - feu-m'ho saber si passa! Agraïments especials a Maria i l'usuari de GitHub [samiulhsnt](https://github.com/samiulhsnt) per ajudar a resoldre això! Vegeu el problema de GitHub [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) per a més informació.
- Ja no utilitzarà CPU quan es faci clic als botons 1 o 2 del ratolí. S'ha reduït lleugerament l'ús de CPU en fer clic a altres botons.
    - Aquesta és una "Versió de Depuració" així que l'ús de CPU pot ser unes 10 vegades més alt en fer clic als botons en aquesta beta vs la versió final
- La simulació de desplaçament del trackpad que s'utilitza per a les funcions "Desplaçament Suau" i "Desplaçament i Navegació" de Mac Mouse Fix ara és encara més precisa. Això pot portar a un millor comportament en algunes situacions.

### Interfície d'usuari

- Correcció automàtica de problemes amb la concessió d'Accés d'Accessibilitat després d'actualitzar des d'una versió anterior de Mac Mouse Fix. Adopta els canvis descrits a les [Notes de la versió 2.2.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- S'ha afegit un botó "Cancel·lar" a la pantalla "Concedir Accés d'Accessibilitat"
- S'ha corregit un problema on la configuració de Mac Mouse Fix no funcionava correctament després d'instal·lar una nova versió de Mac Mouse Fix, perquè la nova versió es connectava a la versió antiga de "Mac Mouse Fix Helper". Ara, Mac Mouse Fix ja no es connectarà a l'antic "Mac Mouse Fix Helper" i desactivarà automàticament la versió antiga quan sigui apropiat.
- Es donen instruccions a l'usuari sobre com arreglar un problema on Mac Mouse Fix no es pot activar correctament a causa d'una altra versió de Mac Mouse Fix present al sistema. Aquest problema només ocorre a macOS Ventura.
- S'ha polit el comportament i les animacions a la pantalla "Concedir Accés d'Accessibilitat"
- Mac Mouse Fix passarà a primer pla quan s'activi. Això millora les interaccions de la interfície en algunes situacions, com quan actives Mac Mouse Fix després que hagi estat desactivat a Configuració del Sistema > General > Elements d'Inici.
- S'han millorat els textos de la interfície a la pantalla "Concedir Accés d'Accessibilitat"
- S'han millorat els textos de la interfície que es mostren quan s'intenta activar Mac Mouse Fix mentre està desactivat a Configuració del Sistema
- S'ha corregit un text en alemany de la interfície

### Sota el capó

- El número de compilació de "Mac Mouse Fix" i el "Mac Mouse Fix Helper" integrat ara estan sincronitzats. Això s'utilitza per evitar que "Mac Mouse Fix" es connecti accidentalment a versions antigues de "Mac Mouse Fix Helper".
- S'ha corregit un problema on algunes dades sobre la llicència i el període de prova de vegades es mostraven incorrectament en iniciar l'aplicació per primera vegada eliminant les dades de la memòria cau de la configuració inicial
- Molta neteja de l'estructura del projecte i del codi font
- S'han millorat els missatges de depuració

---

### Com pots ajudar

Pots ajudar compartint les teves **idees**, **problemes** i **comentaris**!

El millor lloc per compartir les teves **idees** i **problemes** és l'[Assistent de Comentaris](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
El millor lloc per donar **comentaris** ràpids no estructurats és la [Discussió de Comentaris](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

També pots accedir a aquests llocs des de l'aplicació a la pestanya "**ⓘ Sobre**".

**Gràcies** per ajudar a fer Mac Mouse Fix millor! 💙💛❤️