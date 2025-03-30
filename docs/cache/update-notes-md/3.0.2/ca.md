Mac Mouse Fix **3.0.2** porta diverses millores, incloent **desplaçament més suau**, traduccions millorades, i més!

### Desplaçament

- Ara pots aturar les animacions de desplaçament fent un pas en la direcció contrària. Això et permet **'llançar'** i **'atrapar la pàgina'** quan utilitzes 'Suavitat: Alta', similar a un Trackpad.
- Mac Mouse Fix ara envia els esdeveniments de desplaçament més aviat en el cicle de refresc de la pantalla, donant més temps a les aplicacions per processar els esdeveniments i mostrar el desplaçament suaument. Això **millora la taxa de fotogrames**, especialment en llocs web complexos com YouTube.com.
- S'ha millorat la capacitat de resposta de la configuració 'Suavitat: Alta', fent que el desplaçament sigui més fàcil de controlar.
- S'ha millorat el mecanisme introduït a la versió 3.0.1 on la velocitat d'animació esdevé més ràpida a mesura que mous la roda més ràpidament quan utilitzes 'Suavitat: Regular'. A la versió 3.0.2, l'acceleració de l'animació hauria d'aparèixer més consistent i predictible, fent-la més agradable a la vista mentre proporciona un gran control.
- S'ha corregit un problema on la velocitat de desplaçament era massa lenta, especialment quan s'utilitzava l'opció 'Precisió'. Aquest problema es va introduir a la versió 3.0.1. Gràcies a @V-Coba per cridar l'atenció sobre això a [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- S'ha millorat el comportament dins del navegador Arc quan s'utilitza 'Clic i Desplaçament' per 'Apropar o Allunyar'.

### Localització

- S'han actualitzat les traduccions al 🇻🇳 vietnamita. Crèdits a @nghlt!
- S'han millorat algunes traduccions al 🇩🇪 alemany.
- El text dins de Mac Mouse Fix que no té traducció per a l'idioma actual ara mostrarà un valor provisional en lloc de quedar-se en blanc. Això hauria de fer menys confusa la navegació per l'aplicació quan hi ha traduccions que falten.

### Altres

- Mac Mouse Fix ara mostrarà una notificació amb un enllaç a [aquesta guia](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) als usuaris que puguin estar experimentant un error a macOS 13 Ventura i posteriors que pot impedir que Mac Mouse Fix s'activi.
- S'han canviat els ajustaments predeterminats per a ratolins amb 3 botons. Els ajustaments predeterminats ja no inclouen una acció de 'Clic i Desplaçament' per al botó de la roda de desplaçament, ja que és bastant difícil de realitzar. En lloc d'això, els ajustaments predeterminats ara inclouen una acció de 'Mantenir premut' i 'Doble clic'.
- S'ha afegit un consell d'eina a la icona de Mac Mouse Fix a la pestanya Sobre. T'explica com revelar l'arxiu de configuració de Mac Mouse Fix al Finder.
- Moltes millores i neteges internes.

---

També pots consultar la versió anterior [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).