**ℹ️ Nota per als usuaris de Mac Mouse Fix 2**

Amb la introducció de Mac Mouse Fix 3, el model de preus de l'aplicació ha canviat:

- **Mac Mouse Fix 2**\
Continua sent 100% gratuït, i tinc previst continuar donant-hi suport.\
**Omet aquesta actualització** per continuar utilitzant Mac Mouse Fix 2. Descarrega l'última versió de Mac Mouse Fix 2 [aquí](https://redirect.macmousefix.com/?target=mmf2-latest).
- **Mac Mouse Fix 3**\
Gratuït durant 30 dies, costa uns quants dòlars per tenir-lo en propietat.\
**Actualitza ara** per obtenir Mac Mouse Fix 3!

Pots obtenir més informació sobre els preus i les funcions de Mac Mouse Fix 3 al [nou lloc web](https://macmousefix.com/).

Gràcies per utilitzar Mac Mouse Fix! :)

---

**ℹ️ Nota per als compradors de Mac Mouse Fix 3**

Si accidentalment has actualitzat a Mac Mouse Fix 3 sense saber que ja no és gratuït, m'agradaria oferir-te un [reemborsament](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

L'última versió de Mac Mouse Fix 2 continua sent **completament gratuïta**, i la pots descarregar [aquí](https://redirect.macmousefix.com/?target=mmf2-latest).

Em sap greu les molèsties, i espero que tothom estigui d'acord amb aquesta solució!

---

Mac Mouse Fix **3.0.3** està llest per a macOS 15 Sequoia. També corregeix alguns problemes d'estabilitat i proporciona diverses petites millores.

### Suport per a macOS 15 Sequoia

L'aplicació ara funciona correctament sota macOS 15 Sequoia!

- La majoria d'animacions de la interfície estaven trencades sota macOS 15 Sequoia. Ara tot torna a funcionar correctament!
- El codi font ara es pot compilar sota macOS 15 Sequoia. Abans, hi havia problemes amb el compilador Swift que impedien la compilació de l'aplicació.

### Abordant els bloquejos del desplaçament

Des de Mac Mouse Fix 3.0.2 hi ha hagut [múltiples informes](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) de Mac Mouse Fix desactivant-se i reactivant-se periòdicament durant el desplaçament. Això era causat per bloquejos de l'aplicació en segon pla 'Mac Mouse Fix Helper'. Aquesta actualització intenta corregir aquests bloquejos amb els següents canvis:

- El mecanisme de desplaçament intentarà recuperar-se i continuar funcionant en lloc de bloquejar-se quan es trobi amb el cas límit que sembla haver provocat aquests bloquejos.
- He canviat la manera com es gestionen els estats inesperats a l'aplicació en general: En lloc de bloquejar-se immediatament, l'aplicació ara intentarà recuperar-se dels estats inesperats en molts casos.

    - Aquest canvi contribueix a les correccions dels bloquejos de desplaçament descrits anteriorment. També podria prevenir altres bloquejos.

Nota al marge: Mai he pogut reproduir aquests bloquejos al meu ordinador, i encara no estic segur de què els va causar, però basant-me en els informes que he rebut, aquesta actualització hauria d'evitar qualsevol bloqueig. Si encara experimentes bloquejos durant el desplaçament o si els vas experimentar sota la versió 3.0.2, seria valuós que compartissis la teva experiència i dades de diagnòstic a l'Issue de GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Això m'ajudaria a entendre el problema i millorar Mac Mouse Fix. Gràcies!

### Abordant les interrupcions del desplaçament

A la versió 3.0.2 vaig fer canvis en com Mac Mouse Fix envia esdeveniments de desplaçament al sistema en un intent de reduir les interrupcions probablement causades per problemes amb les APIs de VSync d'Apple.

No obstant això, després de proves més exhaustives i comentaris, sembla que el nou mecanisme a la versió 3.0.2 fa que el desplaçament sigui més suau en alguns escenaris però més entretallat en altres. Especialment a Firefox semblava ser notablement pitjor.\
En general, no estava clar que el nou mecanisme realment millorés les interrupcions del desplaçament en general. A més, podria haver contribuït als bloquejos del desplaçament descrits anteriorment.

Per això he desactivat el nou mecanisme i he tornat el mecanisme de VSync per a esdeveniments de desplaçament a com era a Mac Mouse Fix 3.0.0 i 3.0.1.

Consulta l'Issue de GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) per a més informació.

### Reemborsament

Em sap greu els problemes relacionats amb els canvis de desplaçament a les versions 3.0.1 i 3.0.2. Vaig subestimar enormement els problemes que vindrien amb això, i vaig ser lent en abordar aquests problemes. Faré tot el possible per aprendre d'aquesta experiència i ser més cautelós amb aquests canvis en el futur. També m'agradaria oferir un reemborsament a qualsevol persona afectada. Simplement fes clic [aquí](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) si t'interessa.

### Mecanisme d'actualització més intel·ligent

Aquests canvis es van portar de Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) i [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consulta les seves notes de llançament per saber més sobre els detalls. Aquí tens un resum:

- Hi ha un nou mecanisme més intel·ligent que decideix quina actualització mostrar a l'usuari.
- S'ha canviat d'utilitzar el marc d'actualització Sparkle 1.26.0 a l'última versió Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- La finestra que l'aplicació mostra per informar-te que hi ha una nova versió de Mac Mouse Fix disponible ara admet JavaScript, cosa que permet un format més agradable de les notes d'actualització.

### Altres millores i correccions d'errors

- S'ha corregit un problema on el preu de l'aplicació i la informació relacionada es mostraven incorrectament a la pestanya 'Sobre' en alguns casos.
- S'ha corregit un problema on el mecanisme per sincronitzar el desplaçament suau amb la freqüència d'actualització de la pantalla no funcionava correctament mentre s'utilitzaven múltiples pantalles.
- Moltes millores i neteges menors sota el capó.

---

També consulta el llançament anterior [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).