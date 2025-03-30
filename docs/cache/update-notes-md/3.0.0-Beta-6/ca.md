També doneu un cop d'ull als **canvis interessants** introduïts a [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

**3.0.0 Beta 6** porta optimitzacions profundes i poliment, una revisió de la configuració del desplaçament, traduccions al xinès i més!

Aquí teniu tot el que és nou:

## 1. Optimitzacions Profundes

Per a aquesta Beta, he dedicat molt esforç a treure el màxim rendiment de Mac Mouse Fix. I ara estic content d'anunciar que, quan fas clic amb el ratolí a la Beta 6, és **2x** més ràpid comparat amb la beta anterior! I el desplaçament és fins a **4x** més ràpid!

Amb la Beta 6, MMF també desactivarà intel·ligentment parts de si mateix per estalviar CPU i bateria tant com sigui possible.

Per exemple, quan estàs utilitzant un ratolí amb 3 botons però només tens configurades accions per a botons que no es troben al teu ratolí com els botons 4 i 5, Mac Mouse Fix deixarà d'escoltar completament l'entrada de botons del teu ratolí. Això significa 0% d'ús de CPU quan fas clic amb el ratolí! O quan la configuració de desplaçament a MMF coincideix amb el sistema, Mac Mouse Fix deixarà d'escoltar completament l'entrada de la roda de desplaçament. Això significa 0% d'ús de CPU quan et desplaces! Però si configures la funció de Command (⌘)-Desplaçament per fer zoom, Mac Mouse Fix començarà a escoltar l'entrada de la roda de desplaçament - però només mentre mantinguis premuda la tecla Command (⌘). I així successivament.
Així que és realment intel·ligent i només utilitzarà CPU quan sigui necessari!

Això significa que MMF ara no només és el controlador de ratolí més potent, fàcil d'usar i polit per a Mac, sinó que també és un dels més optimitzats i eficients, si no el que més!

## 2. Mida de l'App Reduïda

Amb 16 MB, la Beta 6 és aproximadament 2x més petita que la Beta 5!

Això és un efecte secundari d'eliminar el suport per a versions més antigues de macOS.

## 3. S'ha Eliminat el Suport per a Versions Antigues de macOS

He intentat molt aconseguir que MMF 3 funcioni correctament en versions de macOS anteriors a macOS 11 Big Sur. Però la quantitat de feina per aconseguir que se sentís polit va resultar ser aclaparadora, així que vaig haver de renunciar-hi.

D'ara endavant, la versió més antiga oficialment suportada serà macOS 11 Big Sur.

L'aplicació encara s'obrirà en versions més antigues però hi haurà problemes visuals i potser d'altres tipus. L'aplicació ja no s'obrirà en versions de macOS anteriors a 10.14.4. Això és el que ens permet reduir la mida de l'aplicació a la meitat, ja que 10.14.4 és la versió més antiga de macOS que inclou biblioteques Swift modernes (Vegeu "Swift ABI Stability"), el que significa que aquestes biblioteques Swift ja no han d'estar incloses a l'aplicació.

## 4. Millores en el Desplaçament

La Beta 6 inclou moltes millores en la configuració i la interfície dels nous sistemes de desplaçament introduïts a MMF 3.

### Interfície

- S'ha simplificat i escurçat molt el text de la interfície a la pestanya de Desplaçament. S'han eliminat la majoria de mencions de la paraula "Desplaçament" ja que s'entén pel context.
- S'ha redissenyat la configuració de suavitat del desplaçament perquè sigui molt més clara i permeti algunes opcions addicionals. Ara pots triar entre una "Suavitat" "Desactivada", "Regular" o "Alta", substituint l'antic interruptor "amb Inèrcia". Crec que això és molt més clar i ha fet espai a la interfície per a la nova opció "Simulació del Trackpad".
- Desactivar la nova opció "Simulació del Trackpad" desactiva l'efecte de goma elàstica mentre et desplaces, també evita el desplaçament entre pàgines a Safari i altres aplicacions, i més. Molta gent s'ha molestat per això, especialment aquells amb rodes de desplaçament de gir lliure com les que es troben en alguns ratolins Logitech com el MX Master, però altres ho gaudeixen, així que vaig decidir fer-ho una opció. Espero que la presentació de la funció sigui clara. Si tens suggeriments al respecte, fes-m'ho saber.
- S'ha canviat l'opció "Direcció de Desplaçament Natural" a "Invertir Direcció de Desplaçament". Això significa que la configuració ara inverteix la direcció de desplaçament del sistema i ja no és independent de la direcció de desplaçament del sistema. Tot i que això és possiblement una experiència d'usuari lleugerament pitjor, aquesta nova manera de fer les coses ens permet implementar algunes optimitzacions i fa més transparent per a l'usuari com desactivar completament Mac Mouse Fix per al desplaçament.
- S'ha millorat la manera com la configuració de desplaçament interactua amb el desplaçament modificat en molts casos límit diferents. Per exemple, l'opció "Precisió" ja no s'aplicarà a l'acció "Clic i Desplaçament" per a "Escriptori i Launchpad" ja que aquí és un impediment en lloc de ser útil.
- S'ha millorat la velocitat de desplaçament quan s'utilitza "Clic i Desplaçament" per a "Escriptori i Launchpad" o "Apropar o Allunyar" i altres funcions.
- S'ha eliminat l'enllaç no funcional a la configuració de velocitat de desplaçament del sistema a la pestanya de desplaçament que estava present en versions de macOS anteriors a macOS 13.0 Ventura. No vaig poder trobar una manera de fer funcionar l'enllaç i no és terriblement important.

### Sensació de Desplaçament

- S'ha millorat la corba d'animació per a "Suavitat Regular" (abans accessible desactivant "amb Inèrcia"). Això fa que les coses se sentin més suaus i responsives.
- S'ha millorat la sensació de totes les configuracions de velocitat de desplaçament. La velocitat "Mitjana" i la velocitat "Ràpida" són més ràpides. Hi ha més separació entre les velocitats "Baixa" "Mitjana" i "Alta". L'acceleració a mesura que mous la roda de desplaçament més ràpid se sent més natural i còmoda quan s'utilitza l'opció "Precisió".
- La manera com la velocitat de desplaçament augmenta mentre continues desplaçant-te en una direcció se sentirà més natural i gradual. Estic utilitzant noves corbes matemàtiques per modelar l'acceleració. L'augment de velocitat també serà més difícil d'activar accidentalment.
- Ja no s'augmenta la velocitat de desplaçament quan continues desplaçant-te en una direcció mentre utilitzes la velocitat de desplaçament "macOS".
- S'ha restringit el temps d'animació de desplaçament a un màxim. Si l'animació de desplaçament naturalment trigaria més temps, s'accelerarà per mantenir-se per sota del temps màxim. D'aquesta manera, desplaçar-se fins a la vora de la pàgina amb una roda de gir lliure no farà que el contingut de la pàgina es mogui fora de la pantalla durant tant de temps. Això no hauria d'afectar el desplaçament normal amb una roda que no sigui de gir lliure.
- S'han millorat algunes interaccions al voltant de l'efecte de goma elàstica quan et desplaces fins a la vora d'una pàgina a Safari i altres aplicacions.
- S'ha corregit un problema on "Clic i Desplaçament" i altres funcions relacionades amb el desplaçament no funcionaven correctament després d'actualitzar des d'una versió molt antiga del panell de preferències de Mac Mouse Fix.
- S'ha corregit un problema on els desplaçaments d'un sol píxel s'enviaven amb retard quan s'utilitzava la velocitat de desplaçament "macOS" juntament amb el desplaçament suau.
- S'ha corregit un error on el desplaçament encara era molt ràpid després d'alliberar el modificador de Desplaçament Ràpid. Altres millores al voltant de com la velocitat de desplaçament es transfereix des de desplaçaments anteriors.
- S'ha millorat la manera com la velocitat de desplaçament augmenta amb mides de pantalla més grans.

## 5. Notarització

A partir de 3.0.0 Beta 6, Mac Mouse Fix estarà "Notaritzat". Això significa que no hi haurà més missatges sobre que Mac Mouse Fix és potencialment "Programari Maliciós" quan obris l'aplicació per primera vegada.

Notaritzar la teva aplicació costa $100 per any. Sempre hi estava en contra, ja que semblava hostil cap al programari lliure i de codi obert com Mac Mouse Fix, i també semblava un pas perillós cap a que Apple controlés i tanqués el Mac com fan amb iOS. Però la falta de Notarització va portar a problemes bastant greus, incloent [diverses situacions](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) on ningú podia utilitzar l'aplicació fins que no alliberés una nova versió. Com que Mac Mouse Fix ara serà monetitzat, vaig pensar que finalment era apropiat Notaritzar l'aplicació per a una experiència d'usuari més fàcil i estable.

## 6. Traduccions al Xinès

Mac Mouse Fix ara està disponible en xinès!
Més específicament, està disponible en:

- Xinès, Tradicional
- Xinès, Simplificat
- Xinès (Hong Kong)

Moltes gràcies a @groverlynn per proporcionar totes aquestes traduccions i per actualitzar-les durant les betes i comunicar-se amb mi. Mira la seva sol·licitud de pull aquí: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Tot el Demés

A part dels canvis llistats anteriorment, la Beta 6 també inclou moltes millores més petites.

- S'han eliminat diverses opcions de les Accions "Clic", "Clic i Mantenir" i "Clic i Desplaçament" perquè vaig pensar que eren redundants ja que la mateixa funcionalitat es pot aconseguir d'altres maneres i ja que això neteja molt els menús. Les tornaré a afegir si la gent es queixa. Així que si trobes a faltar aquestes opcions - si us plau, queixa't.
- La direcció de Clic i Arrossegar ara coincidirà amb la direcció de lliscament del trackpad fins i tot quan "Desplaçament natural" està desactivat a Configuració del Sistema > Trackpad. Abans, Clic i Arrossegar sempre es comportava com lliscar al trackpad amb "Desplaçament natural" activat.
- S'ha corregit un problema on els cursors desapareixien i després reapareixien en un altre lloc quan s'utilitzava una Acció de "Clic i Arrossegar" durant una gravació de pantalla o quan s'utilitzava el programari DisplayLink.
- S'ha corregit el centrat del "+" al Camp "+" a la pestanya de Botons
- Diverses millores visuals a la pestanya de botons. La paleta de colors del Camp "+" i la Taula d'Accions s'ha redissenyat per veure's correctament quan s'utilitza l'opció de macOS "Permetre tenyir el fons de pantalla a les finestres". Les vores de la Taula d'Accions ara tenen un color transparent que es veu més dinàmic i s'ajusta al seu entorn.
- S'ha fet que quan afegeixes moltes accions a la taula d'accions i la finestra de Mac Mouse Fix creix, creixerà exactament tan gran com la pantalla (o com la pantalla menys el dock si no tens activat l'ocultament del dock) i després s'aturarà. Quan afegeixes encara més accions, la taula d'accions començarà a desplaçar-se.
- Aquesta Beta ara suporta un nou pagament on pots comprar una llicència en dòlars americans com s'anuncia. Abans només podies comprar una llicència en euros. Les antigues llicències en euros seguiran sent suportades, per descomptat.
- S'ha corregit un problema on el desplaçament amb inèrcia de vegades no s'iniciava quan s'utilitzava la funció "Desplaçament i Navegació".
- Quan la finestra de Mac Mouse Fix es redimensiona durant un canvi de pestanya, ara es reposicionarà perquè no se superposi amb el Dock
- S'ha corregit el parpelleig en alguns elements de la interfície quan es canvia de la pestanya Botons a una altra pestanya
- S'ha millorat l'aparença de l'animació que el Camp "+" reprodueix després de gravar una entrada. Especialment en versions de macOS anteriors a Ventura, on l'ombra del Camp "+" apareixeria defectuosa durant l'animació.
- S'han desactivat les notificacions que llisten diversos botons que han estat capturats/ja no són capturats per Mac Mouse Fix que apareixien quan s'iniciava l'aplicació per primera vegada o quan es carregava un preset. Vaig pensar que aquests missatges eren distracció i lleugerament aclaparadors i no realment útils en aquests contextos.
- S'ha redissenyat la Pantalla de Concedir Accés d'Accessibilitat. Ara mostrarà informació sobre per què Mac Mouse Fix necessita Accés d'Accessibilitat en línia en lloc d'enllaçar al lloc web i és una mica més clara i té una disposició visualment més agradable.
- S'ha actualitzat l'enllaç d'Agraïments a la pestanya Sobre.
- S'han millorat els missatges d'error quan Mac Mouse Fix no es pot activar perquè hi ha una altra versió present al sistema. El missatge ara es mostrarà en una finestra d'alerta flotant que sempre es manté per sobre d'altres finestres fins que es descarta en lloc d'una Notificació Toast que desapareix quan es fa clic a qualsevol lloc. Això hauria de fer més fàcil seguir els passos de solució suggerits.
- S'han corregit alguns problemes amb la renderització de markdown en versions de macOS anteriors a Ventura. MMF ara utilitzarà una solució de renderització de markdown personalitzada per a totes les versions de macOS, inclosa Ventura. Abans estàvem utilitzant una API del sistema introduïda a Ventura però això portava a inconsistències. El markdown s'utilitza per afegir enllaços i èmfasi al text a tota la interfície.
- S'han polit les interaccions al voltant d'activar l'accés d'accessibilitat.
- S'ha corregit un problema on la finestra de l'aplicació de vegades s'obria sense mostrar cap contingut fins que canviaves a una de les pestanyes.
- S'ha corregit un problema amb el Camp "+" on de vegades no podies afegir una nova acció tot i que mostrava un efecte de hover indicant que pots introduir una acció.
- S'ha corregit un bloqueig i diversos altres petits problemes que de vegades passaven quan es movia el punter del ratolí dins del Camp "+"
- S'ha corregit un problema on un popover que apareix a la pestanya Botons quan el teu ratolí no sembla ajustar-se a la configuració actual de botons de vegades tindria tot el text en negreta.
- S'han actualitzat totes les mencions de l'antiga llicència MIT a la nova llicència MMF. Els nous arxius creats per al projecte ara contindran una capçalera autogenerada que menciona la llicència MMF.
- S'ha fet que canviar a la pestanya Botons activi MMF per al Desplaçament. D'altra manera, no podies gravar gestos de Clic i Desplaçament.
- S'han corregit alguns problemes on els noms dels botons no es mostraven correctament a la Taula d'Accions en algunes situacions.
- S'ha corregit un error on la secció de prova a la pantalla Sobre es veuria defectuosa quan s'obre l'aplicació i després es canvia a la pestanya de prova després que la prova hagi expirat.
- S'ha corregit un error on l'enllaç Activar Llicència a la secció de prova de la Pestanya Sobre de vegades no reaccionava als clics.
- S'ha corregit una fuita de memòria quan s'utilitza la funció "Clic i Arrossegar" per a "Espais i Mission Control".
- S'ha activat el runtime endurit a l'aplicació principal de Mac Mouse Fix, millorant la seguretat
- Molta neteja de codi, reestructuració del projecte
- S'han corregit diversos altres errors
- S'han corregit diverses fuites de memòria
- Diversos petits ajustos de text de la interfície
- Les revisions de diversos sistemes interns també han millorat la robustesa i el comportament en casos límit

## 8. Com Pots Ajudar

Pots ajudar compartint les teves **idees**, **problemes** i **comentaris**!

El millor lloc per compartir les teves **idees** i **problemes** és l'[Assistent de Comentaris](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
El millor lloc per donar **comentaris** ràpids no estructurats és la [Discussió de Comentaris](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

També pots accedir a aquests llocs des de dins de l'aplicació a la pestanya "**ⓘ Sobre**".

**Gràcies** per ajudar a fer que Mac Mouse Fix sigui el millor possible! 🙌:)