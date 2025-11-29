Mac Mouse Fix **3.0.3** està llest per a macOS 15 Sequoia. També soluciona alguns problemes d'estabilitat i proporciona diverses millores petites.

### Suport per a macOS 15 Sequoia

L'aplicació ara funciona correctament amb macOS 15 Sequoia!

- La majoria d'animacions de la interfície no funcionaven amb macOS 15 Sequoia. Ara tot torna a funcionar correctament!
- El codi font ara es pot compilar amb macOS 15 Sequoia. Abans, hi havia problemes amb el compilador Swift que impedien la compilació de l'aplicació.

### Solució dels bloqueigs durant el desplaçament

Des de Mac Mouse Fix 3.0.2 hi ha hagut [múltiples informes](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) de Mac Mouse Fix desactivant-se i reactivant-se periòdicament mentre es desplaça. Això era causat per bloqueigs de l'aplicació en segon pla 'Mac Mouse Fix Helper'. Aquesta actualització intenta solucionar aquests bloqueigs, amb els següents canvis:

- El mecanisme de desplaçament intentarà recuperar-se i continuar funcionant en lloc de bloquejar-se, quan trobi el cas límit que sembla haver causat aquests bloqueigs.
- He canviat la manera en què es gestionen els estats inesperats a l'aplicació de forma més general: En lloc de bloquejar-se sempre immediatament, l'aplicació ara intentarà recuperar-se dels estats inesperats en molts casos.
    
    - Aquest canvi contribueix a les correccions dels bloqueigs de desplaçament descrits anteriorment. També podria prevenir altres bloqueigs.
  
Nota: Mai he pogut reproduir aquests bloqueigs a la meva màquina, i encara no estic segur del que els va causar, però basant-me en els informes que he rebut, aquesta actualització hauria de prevenir qualsevol bloqueig. Si encara experimentes bloqueigs mentre et desplaces o si *vas* experimentar bloqueigs amb la versió 3.0.2, seria valuós que compartissis la teva experiència i dades de diagnòstic a l'Issue de GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Això m'ajudaria a entendre el problema i millorar Mac Mouse Fix. Gràcies!

### Solució dels entrebancs durant el desplaçament

A la versió 3.0.2 vaig fer canvis en com Mac Mouse Fix envia esdeveniments de desplaçament al sistema en un intent de reduir els entrebancs probablement causats per problemes amb les APIs VSync d'Apple.

No obstant això, després de proves més extenses i comentaris, sembla que el nou mecanisme de la versió 3.0.2 fa que el desplaçament sigui més fluid en alguns escenaris però més entrebancós en altres. Especialment a Firefox semblava ser notablement pitjor. \
En general, no estava clar que el nou mecanisme realment millorés els entrebancs de desplaçament en tots els casos. A més, podria haver contribuït als bloqueigs de desplaçament descrits anteriorment.

Per això he desactivat el nou mecanisme i he revertit el mecanisme VSync per als esdeveniments de desplaçament a com era a Mac Mouse Fix 3.0.0 i 3.0.1.

Consulta l'Issue de GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) per a més informació.

### Reemborsament

Lamento les molèsties relacionades amb els canvis de desplaçament a les versions 3.0.1 i 3.0.2. Vaig subestimar enormement els problemes que vindrien amb això, i vaig ser lent a l'hora d'abordar aquests problemes. Faré tot el possible per aprendre d'aquesta experiència i ser més acurat amb aquests canvis en el futur. També voldria oferir un reemborsament a qualsevol persona afectada. Només has de fer clic [aquí](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) si t'interessa.

### Mecanisme d'actualització més intel·ligent

Aquests canvis s'han portat des de Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) i [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consulta les seves notes de llançament per conèixer més detalls. Aquí tens un resum:

- Hi ha un nou mecanisme més intel·ligent que decideix quina actualització mostrar a l'usuari.
- S'ha canviat del framework d'actualització Sparkle 1.26.0 a l'últim Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- La finestra que l'aplicació mostra per informar-te que hi ha una nova versió de Mac Mouse Fix disponible ara admet JavaScript, cosa que permet un format més agradable de les notes d'actualització.

### Altres millores i correccions d'errors

- S'ha solucionat un problema on el preu de l'aplicació i la informació relacionada es mostraven incorrectament a la pestanya 'Quant a' en alguns casos.
- S'ha solucionat un problema on el mecanisme per sincronitzar el desplaçament fluid amb la freqüència de refresc de la pantalla no funcionava correctament mentre s'utilitzaven múltiples pantalles.
- Moltes millores i neteja menors sota el capó.

---

També consulta el llançament anterior [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).