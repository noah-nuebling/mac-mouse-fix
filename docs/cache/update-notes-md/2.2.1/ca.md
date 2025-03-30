Mac Mouse Fix **2.2.1** ofereix **suport complet per a macOS Ventura** entre altres canvis.

### Suport per a Ventura!
Mac Mouse Fix ara és totalment compatible i se sent natiu a macOS 13 Ventura.
Agraïments especials a [@chamburr](https://github.com/chamburr) que va ajudar amb el suport de Ventura a l'Issue de GitHub [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Els canvis inclouen:

- Actualització de la interfície per concedir l'Accés d'Accessibilitat per reflectir els nous Ajustaments del Sistema de Ventura
- Mac Mouse Fix es mostrarà correctament sota el nou menú **Ajustaments del Sistema > Elements d'Inici** de Ventura
- Mac Mouse Fix reaccionarà adequadament quan estigui desactivat a **Ajustaments del Sistema > Elements d'Inici**

### S'ha eliminat el suport per a versions anteriors de macOS

Malauradament, Apple només permet desenvolupar _per a_ macOS 10.13 **High Sierra i posteriors** quan es desenvolupa _des de_ macOS 13 Ventura.

Per tant, la **versió mínima compatible** ha augmentat de 10.11 El Capitan a 10.13 High Sierra.

### Correccions d'errors

- S'ha corregit un problema on Mac Mouse Fix canviava el comportament del desplaçament d'algunes **tauletes de dibuix**. Vegeu l'Issue de GitHub [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- S'ha corregit un problema on les **dreceres de teclat** que incloïen la tecla 'A' no es podien enregistrar. Corregeix l'Issue de GitHub [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- S'ha corregit un problema on alguns **remapatges de botons** no funcionaven correctament quan s'utilitzava una distribució de teclat no estàndard.
- S'ha corregit un error als '**Ajustaments específics per aplicació**' quan s'intentava afegir una aplicació sense 'Bundle ID'. Podria ajudar amb l'Issue de GitHub [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- S'ha corregit un error quan s'intentava afegir aplicacions sense nom als '**Ajustaments específics per aplicació**'. Resol l'Issue de GitHub [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Agraïments especials a [jeongtae](https://github.com/jeongtae) que va ser de gran ajuda per descobrir el problema!
- Més correccions d'errors menors i millores internes.