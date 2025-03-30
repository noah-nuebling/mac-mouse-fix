També podeu consultar les **novetats interessants** introduïdes a [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

Mac Mouse Fix **2.2.0** inclou diverses millores d'usabilitat i correccions d'errors!

### La reassignació a tecles de funció exclusives d'Apple ara és millor

L'última actualització, 2.1.0, va introduir una nova funció interessant que et permet reassignar els botons del ratolí a qualsevol tecla del teclat, fins i tot les tecles de funció que només es troben als teclats d'Apple. La versió 2.2.0 inclou més millores i refinaments d'aquesta funció:

- Ara pots mantenir premuda la tecla Opció (⌥) per reassignar a tecles que només es troben als teclats d'Apple, fins i tot si no tens un teclat d'Apple a mà.
- Els símbols de les tecles de funció tenen una aparença millorada, integrant-se millor amb la resta del text.
- S'ha desactivat la possibilitat de reassignar al Bloq Maj. No funcionava com s'esperava.

### Afegeix / elimina Accions més fàcilment

Alguns usuaris tenien problemes per descobrir que es poden afegir i eliminar Accions de la Taula d'Accions. Per fer-ho més fàcil d'entendre, la versió 2.2.0 inclou els següents canvis i noves funcions:

- Ara pots eliminar Accions fent clic dret sobre elles.
  - Això hauria de fer més fàcil descobrir l'opció d'eliminar Accions.
  - El menú del clic dret mostra un símbol del botó '-'. Això hauria d'ajudar a cridar l'atenció sobre el _botó_ '-', que al seu torn hauria de cridar l'atenció sobre el botó '+'. Això esperem que faci l'opció d'**afegir** Accions més fàcil de descobrir.
- Ara pots afegir Accions a la Taula d'Accions fent clic dret en una fila buida.
- El botó '-' ara només està actiu quan hi ha una Acció seleccionada. Això hauria de fer més clar que el botó '-' elimina l'Acció seleccionada.
- L'alçada predeterminada de la finestra s'ha augmentat perquè hi hagi una fila buida visible on es pugui fer clic dret per afegir una Acció.
- Els botons '+' i '-' ara tenen consells d'eines.

### Millores en Clic i Arrossega

El llindar per activar Clic i Arrossega s'ha augmentat de 5 píxels a 7 píxels. Això fa més difícil activar accidentalment Clic i Arrossega, mentre encara permet als usuaris canviar d'Espais, etc. utilitzant moviments petits i còmodes.

### Altres canvis en la interfície

- S'ha millorat l'aparença de la Taula d'Accions.
- Diverses altres millores en la interfície.

### Correccions d'errors

- S'ha corregit un problema on la interfície no es desactivava en iniciar MMF mentre estava desactivat.
- S'ha eliminat l'opció oculta "Botó 3 Clic i Arrossega".
  - En seleccionar-la, l'aplicació es bloquejava. Vaig crear aquesta opció per fer Mac Mouse Fix més compatible amb Blender. Però en la seva forma actual, no és gaire útil per als usuaris de Blender perquè no es pot combinar amb modificadors de teclat. Tinc previst millorar la compatibilitat amb Blender en una futura versió.