També doneu un cop d'ull a les **millores interessants** introduïdes a [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6)!


---

**3.0.0 Beta 7** porta diverses petites millores i correccions d'errors.

Aquí teniu tot el que és nou:

**Millores**

- S'han afegit **traduccions al coreà**. Moltes gràcies a @jeongtae! (El trobareu a [GitHub](https://github.com/jeongtae))
- S'ha fet el **desplaçament** amb l'opció 'Suavitat: Alta' **encara més suau**, canviant només la velocitat gradualment, en lloc de tenir salts sobtats en la velocitat de desplaçament mentre mous la roda. Això hauria de fer que el desplaçament se senti una mica més suau i més fàcil de seguir amb els ulls sense fer les coses menys responsives. El desplaçament amb 'Suavitat: Alta' ara utilitza un 30% més de CPU, al meu ordinador va passar d'un 1,2% d'ús de CPU en desplaçament continu a un 1,6%. Així que el desplaçament segueix sent molt eficient i espero que això no suposi una diferència per a ningú. Moltes gràcies a [MOS](https://mos.caldis.me/), que va inspirar aquesta funció i el seu 'Monitor de Desplaçament' que vaig utilitzar per implementar la funció.
- Mac Mouse Fix ara **gestiona entrades de botons de totes les fonts**. Abans, Mac Mouse Fix només gestionava entrades de ratolins que reconeixia. Crec que això podria ajudar amb la compatibilitat amb certs ratolins en casos extrems, com quan s'utilitza un Hackintosh, però també farà que Mac Mouse Fix capturi entrades de botons generades artificialment per altres aplicacions, cosa que podria provocar problemes en altres casos extrems. Feu-me saber si això us causa algun problema, i ho abordaré en futures actualitzacions.
- S'ha refinat la sensació i el poliment dels gestos 'Clic i Desplaçament' per a 'Escriptori i Launchpad' i 'Clic i Desplaçament' per 'Moure's entre Espais'.
- Ara es té en compte la densitat d'informació d'un idioma quan es calcula el **temps que es mostren les notificacions**. Abans d'això, les notificacions només romanien visibles durant un temps molt curt en idiomes amb alta densitat d'informació com el xinès o el coreà.
- S'han habilitat **diferents gestos** per moure's entre **Espais**, obrir el **Control de Missió**, o obrir l'**Exposé d'Aplicacions**. A la Beta 6, vaig fer que aquestes accions només estiguessin disponibles a través del gest 'Clic i Arrossegar' - com a experiment per veure quanta gent realment es preocupava de poder accedir a aquestes accions d'altres maneres. Sembla que alguns sí que ho fan, així que ara ho he fet possible de nou accedir a aquestes accions mitjançant un simple 'Clic' d'un botó o mitjançant 'Clic i Desplaçament'.
- S'ha fet possible **Rotar** mitjançant un gest de **Clic i Desplaçament**.
- S'ha **millorat** la manera com funciona l'opció de **Simulació del Trackpad** en alguns escenaris. Per exemple, quan es desplaça horitzontalment per eliminar un missatge al Mail, la direcció en què es mou el missatge ara està invertida, cosa que espero que se senti una mica més natural i consistent per a la majoria de la gent.
- S'ha afegit una funció per **reassignar** al **Clic Primari** o **Clic Secundari**. Ho he implementat perquè el botó dret del meu ratolí favorit es va trencar. Aquestes opcions estan ocultes per defecte. Pots veure-les mantenint premuda la tecla Opció mentre selecciones una acció.
  - Actualment falten traduccions per al xinès i el coreà, així que si voleu contribuir amb traduccions per a aquestes funcions, seria molt apreciat!

**Correccions d'Errors**

- S'ha corregit un error on la **direcció de 'Clic i Arrossegar'** per a 'Control de Missió i Espais' estava **invertida** per a les persones que mai han canviat l'opció 'Desplaçament natural' a la Configuració del Sistema. Ara, la direcció dels gestos 'Clic i Arrossegar' a Mac Mouse Fix hauria de coincidir sempre amb la direcció dels gestos al teu Trackpad o Magic Mouse. Si vols una opció separada per invertir la direcció de 'Clic i Arrossegar', en lloc de seguir la Configuració del Sistema, fes-m'ho saber.
- S'ha corregit un error on els **dies gratuïts** **augmentaven massa ràpidament** per a alguns usuaris. Si t'ha afectat això, fes-m'ho saber i veuré què puc fer.
- S'ha corregit un problema a macOS Sonoma on la barra de pestanyes no es mostrava correctament.
- S'ha corregit la inestabilitat quan s'utilitza la velocitat de desplaçament 'macOS' mentre s'utilitza 'Clic i Desplaçament' per obrir el Launchpad.
- S'ha corregit un error on l'aplicació 'Mac Mouse Fix Helper' (que s'executa en segon pla quan Mac Mouse Fix està activat) es bloquejava de vegades en gravar una drecera de teclat.
- S'ha corregit un error on Mac Mouse Fix es bloquejava en intentar capturar esdeveniments artificials generats per [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma)
- S'ha corregit un problema on el nom d'alguns ratolins mostrat al diàleg 'Restaurar valors per defecte...' contenia el fabricant dues vegades.
- S'ha fet menys probable que 'Clic i Arrossegar' per a 'Control de Missió i Espais' es quedi encallat quan l'ordinador va lent.
- S'ha corregit l'ús de 'Force Touch' en les cadenes de la interfície on hauria de ser 'Force click'.
- S'ha corregit un error que ocorria en certes configuracions, on obrir el Launchpad o mostrar l'Escriptori mitjançant 'Clic i Desplaçament' no funcionava si deixaves anar el botó mentre l'animació de transició encara estava en curs.


**Més**

- Diverses millores internes, millores d'estabilitat, neteja interna i més.

## Com Pots Ajudar

Pots ajudar compartint les teves **idees**, **problemes** i **comentaris**!

El millor lloc per compartir les teves **idees** i **problemes** és l'[Assistent de Comentaris](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
El millor lloc per donar **comentaris** ràpids no estructurats és la [Discussió de Comentaris](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

També pots accedir a aquests llocs des de dins de l'aplicació a la pestanya '**ⓘ Sobre**'.

**Gràcies** per ajudar a fer Mac Mouse Fix millor! 😎:)