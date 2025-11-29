Mac Mouse Fix **3.0.5** corregeix diversos errors, millora el rendiment i afegeix un toc de poliment a l'aplicació. \
També és compatible amb macOS 26 Tahoe.

### Simulació millorada del desplaçament del trackpad

- El sistema de desplaçament ara pot simular un toc amb dos dits al trackpad per fer que les aplicacions deixin de desplaçar-se.
    - Això soluciona un problema quan s'executaven aplicacions d'iPhone o iPad, on el desplaçament sovint continuava després que l'usuari decidís aturar-lo.
- S'ha corregit la simulació inconsistent d'aixecar els dits del trackpad.
    - Això pot haver causat un comportament subòptim en algunes situacions.



### Compatibilitat amb macOS 26 Tahoe

Quan s'executa la versió Beta de macOS 26 Tahoe, l'aplicació ara és utilitzable i la majoria de la interfície funciona correctament.



### Millora del rendiment

S'ha millorat el rendiment del gest de clicar i arrossegar per "Desplaçar i navegar". \
En les meves proves, l'ús de CPU s'ha reduït aproximadament un 50%!

**Context**

Durant el gest "Desplaçar i navegar", Mac Mouse Fix dibuixa un cursor de ratolí fals en una finestra transparent, mentre bloqueja el cursor de ratolí real al seu lloc. Això garanteix que puguis continuar desplaçant l'element de la interfície on vas començar a desplaçar-te, independentment de fins on moguis el ratolí.

La millora del rendiment s'ha aconseguit desactivant la gestió d'esdeveniments predeterminada de macOS en aquesta finestra transparent, que de totes maneres no s'utilitzava.





### Correccions d'errors

- Ara s'ignoren els esdeveniments de desplaçament de les tauletes gràfiques Wacom.
    - Abans, Mac Mouse Fix causava un desplaçament erràtic a les tauletes Wacom, tal com va informar @frenchie1980 a l'Issue de GitHub [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Gràcies!)
    
- S'ha corregit un error on el codi de Swift Concurrency, que es va introduir com a part del nou sistema de llicències a Mac Mouse Fix 3.0.4, no s'executava al fil correcte.
    - Això causava fallades a macOS Tahoe, i també probablement causava altres errors esporàdics relacionats amb les llicències.
- S'ha millorat la robustesa del codi que descodifica les llicències fora de línia.
    - Això soluciona un problema a les API d'Apple que feia que la validació de llicències fora de línia sempre fallés al meu Mac Mini Intel. Assumeixo que això passava a tots els Mac Intel, i que era la raó per la qual l'error "S'han acabat els dies gratuïts" (que ja es va abordar a la versió 3.0.4) encara es produïa per a algunes persones, tal com va informar @toni20k5267 a l'Issue de GitHub [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Gràcies!)
        - Si has experimentat l'error "S'han acabat els dies gratuïts", ho sento molt! Pots obtenir un reemborsament [aquí](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Millores d'experiència d'usuari

- S'han desactivat els diàlegs que proporcionaven solucions pas a pas per a errors de macOS que impedien als usuaris activar Mac Mouse Fix.
    - Aquests problemes només es produïen a macOS 13 Ventura i 14 Sonoma. Ara, aquests diàlegs només apareixen a les versions de macOS on són rellevants.
    - Els diàlegs també són una mica més difícils d'activar: abans, de vegades apareixien en situacions on no eren gaire útils.
    
- S'ha afegit un enllaç "Activar llicència" directament a la notificació "S'han acabat els dies gratuïts".
    - Això fa que activar una llicència de Mac Mouse Fix sigui encara més fàcil!

### Millores visuals

- S'ha millorat lleugerament l'aspecte de la finestra "Actualització de programari". Ara s'adapta millor a macOS 26 Tahoe.
    - Això s'ha fet personalitzant l'aspecte predeterminat del framework "Sparkle 1.27.3" que Mac Mouse Fix utilitza per gestionar les actualitzacions.
- S'ha corregit un problema on el text a la part inferior de la pestanya Quant a de vegades es tallava en xinès, fent la finestra una mica més ampla.
- S'ha corregit que el text a la part inferior de la pestanya Quant a estigués lleugerament descentrat.
- S'ha corregit un error que feia que l'espai sota l'opció "Drecera de teclat..." a la pestanya Botons fos massa petit.

### Canvis interns

- S'ha eliminat la dependència del framework "SnapKit".
    - Això redueix lleugerament la mida de l'aplicació de 19,8 a 19,5 MB.
- Diverses altres petites millores al codi.

*Editat amb l'excel·lent assistència de Claude.*

---

També pots consultar la versió anterior [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).