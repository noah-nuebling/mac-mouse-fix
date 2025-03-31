¡Echa un vistazo también a las **interesantes mejoras** introducidas en [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6)!


---

**3.0.0 Beta 7** trae varias pequeñas mejoras y correcciones de errores.

Aquí está todo lo nuevo:

**Mejoras**

- Añadidas **traducciones al coreano**. ¡Muchas gracias a @jeongtae! (Encuéntralo en [GitHub](https://github.com/jeongtae))
- El **desplazamiento** con la opción 'Suavidad: Alta' es **aún más suave**, ya que solo cambia la velocidad gradualmente, en lugar de tener saltos repentinos en la velocidad de desplazamiento al mover la rueda. Esto debería hacer que el desplazamiento se sienta un poco más suave y sea más fácil de seguir con los ojos sin hacer las cosas menos receptivas. El desplazamiento con 'Suavidad: Alta' usa aproximadamente un 30% más de CPU ahora, en mi computadora pasó de usar 1.2% de CPU al desplazarse continuamente a 1.6%. Así que el desplazamiento sigue siendo altamente eficiente y espero que esto no suponga una diferencia para nadie. Muchas gracias a [MOS](https://mos.caldis.me/), que inspiró esta función y cuyo 'Monitor de Desplazamiento' utilicé para ayudar a implementar la función.
- Mac Mouse Fix ahora **maneja entradas de botones de todas las fuentes**. Antes, Mac Mouse Fix solo manejaba entradas de ratones que reconocía. Creo que esto podría ayudar con la compatibilidad con ciertos ratones en casos extremos, como cuando se usa un Hackintosh, pero también hará que Mac Mouse Fix capte entradas de botones generadas artificialmente por otras aplicaciones, lo que podría causar problemas en otros casos extremos. Hazme saber si esto te causa algún problema y lo abordaré en futuras actualizaciones.
- Refinado el tacto y pulido de los gestos 'Clic y Desplazamiento' para 'Escritorio y Launchpad' y 'Clic y Desplazamiento' para 'Moverse Entre Espacios'.
- Ahora se tiene en cuenta la densidad de información de un idioma al calcular el **tiempo que se muestran las notificaciones**. Antes de esto, las notificaciones solo permanecían visibles durante un tiempo muy corto en idiomas con alta densidad de información como el chino o el coreano.
- Habilitados **diferentes gestos** para moverse entre **Espacios**, abrir **Mission Control** o abrir **Exposé de Aplicaciones**. En Beta 6, hice que estas acciones solo estuvieran disponibles a través del gesto 'Clic y Arrastrar' - como un experimento para ver cuántas personas realmente les importaba poder acceder a esas acciones de otras maneras. Parece que a algunos sí les importa, así que ahora he vuelto a hacer posible acceder a estas acciones mediante un simple 'Clic' de un botón o mediante 'Clic y Desplazamiento'.
- Se ha hecho posible **Rotar** mediante un gesto de **Clic y Desplazamiento**.
- **Mejorada** la forma en que funciona la opción de **Simulación del Trackpad** en algunos escenarios. Por ejemplo, cuando se desplaza horizontalmente para eliminar un mensaje en Mail, la dirección en que se mueve el mensaje ahora está invertida, lo que espero se sienta más natural y consistente para la mayoría de las personas.
- Añadida una función para **reasignar** al **Clic Primario** o **Clic Secundario**. Implementé esto porque se rompió el botón derecho de mi ratón favorito. Estas opciones están ocultas por defecto. Puedes verlas manteniendo presionada la tecla Opción mientras seleccionas una acción.
  - Actualmente faltan traducciones para chino y coreano, así que si te gustaría contribuir con traducciones para estas funciones, ¡sería muy apreciado!

**Correcciones de Errores**

- Corregido un error donde la **dirección de 'Clic y Arrastrar'** para 'Mission Control y Espacios' estaba **invertida** para personas que nunca han cambiado la opción 'Desplazamiento natural' en Ajustes del Sistema. Ahora, la dirección de los gestos 'Clic y Arrastrar' en Mac Mouse Fix debería coincidir siempre con la dirección de los gestos en tu Trackpad o Magic Mouse. Si quieres una opción separada para invertir la dirección de 'Clic y Arrastrar', en lugar de que siga los Ajustes del Sistema, házmelo saber.
- Corregido un error donde los **días gratuitos** **aumentaban demasiado rápido** para algunos usuarios. Si te afectó esto, házmelo saber y veré qué puedo hacer.
- Corregido un problema en macOS Sonoma donde la barra de pestañas no se mostraba correctamente.
- Corregida la inestabilidad al usar la velocidad de desplazamiento 'macOS' mientras se usa 'Clic y Desplazamiento' para abrir Launchpad.
- Corregido un fallo donde la aplicación 'Mac Mouse Fix Helper' (que se ejecuta en segundo plano cuando Mac Mouse Fix está habilitado) se bloqueaba a veces al grabar un atajo de teclado.
- Corregido un error donde Mac Mouse Fix se bloqueaba al intentar captar eventos artificiales generados por [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma)
- Corregido un problema donde el nombre de algunos ratones mostrados en el diálogo 'Restaurar valores predeterminados...' contenía el fabricante dos veces.
- Se ha reducido la probabilidad de que 'Clic y Arrastrar' para 'Mission Control y Espacios' se quede atascado cuando el ordenador va lento.
- Corregido el uso de 'Force Touch' en las cadenas de la interfaz donde debería ser 'Force click'.
- Corregido un error que ocurría en ciertas configuraciones, donde abrir Launchpad o mostrar el Escritorio mediante 'Clic y Desplazamiento' no funcionaba si soltabas el botón mientras la animación de transición aún estaba en curso.

**Más**

- Varias mejoras internas, mejoras de estabilidad, limpieza interna y más.

## Cómo Puedes Ayudar

¡Puedes ayudar compartiendo tus **ideas**, **problemas** y **comentarios**!

El mejor lugar para compartir tus **ideas** y **problemas** es el [Asistente de Comentarios](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
El mejor lugar para dar **comentarios** rápidos no estructurados es la [Discusión de Comentarios](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

También puedes acceder a estos lugares desde dentro de la aplicación en la pestaña '**ⓘ Acerca de**'.

**¡Gracias** por ayudar a mejorar Mac Mouse Fix! 😎:)