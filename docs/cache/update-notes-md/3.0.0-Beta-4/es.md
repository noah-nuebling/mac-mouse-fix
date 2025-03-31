¡Comprueba también **las novedades** en [3.0.0 Beta 3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-3)!

---

**3.0.0 Beta 4** trae una nueva **opción "Restaurar valores predeterminados..."** así como muchas **mejoras de calidad de vida** y **correcciones de errores**!

Aquí está **todo** lo **nuevo**:

## 1. Opción "Restaurar valores predeterminados..."

Ahora hay un botón "**Restaurar valores predeterminados...**" en la pestaña "Botones".
Esto te permite sentirte aún más **cómodo** mientras **experimentas** con la configuración.

Hay **2 configuraciones predeterminadas** disponibles:

1. La "Configuración predeterminada para ratones con **5+ botones**" es super potente y cómoda. De hecho, te permite hacer **todo** lo que haces con un **trackpad**. ¡Todo usando los 2 **botones laterales** que están justo donde descansa tu **pulgar**! Pero por supuesto solo está disponible en ratones con 5 o más botones.
2. La "Configuración predeterminada para ratones con **3 botones**" aún te permite hacer las **cosas más importantes** que haces en un trackpad, incluso en un ratón que solo tiene 3 botones.

Me he esforzado en hacer esta función **inteligente**:

- Cuando inicias MMF por primera vez, **seleccionará automáticamente** el preset que **mejor se adapte a tu ratón**.
- Cuando vayas a restaurar los valores predeterminados, Mac Mouse Fix te **mostrará** qué **modelo de ratón** estás usando y su **número de botones**, para que puedas elegir fácilmente cuál de los dos presets usar. También **preseleccionará** el preset que **mejor se adapte a tu ratón**.
- Cuando cambies a un **nuevo ratón** que no se ajuste a tu configuración actual, ¡un popup en la pestaña Botones te **recordará** cómo **cargar** la configuración recomendada para tu ratón!
- Toda la **interfaz** que rodea esto es muy **simple**, **bella** y **anima** de manera agradable.

¡Espero que encuentres esta función **útil** y **fácil de usar**! Pero hazme saber si tienes algún problema.
¿Hay algo **raro** o **poco intuitivo**? ¿Los **popups** aparecen **demasiado** a menudo o en **situaciones inapropiadas**? ¡**Cuéntame** tu experiencia!

## 2. Mac Mouse Fix temporalmente gratuito en algunos países

Hay algunos **países** donde el **proveedor de pagos** de Mac Mouse Fix, Gumroad, **no funciona** actualmente.
¡Mac Mouse Fix ahora es **gratuito** en **esos países** hasta que pueda proporcionar un método de pago alternativo!

Si estás en uno de los países gratuitos, la información sobre esto se **mostrará** en la **pestaña Acerca de** y al **introducir una clave de licencia**

Si es **imposible comprar** Mac Mouse Fix en tu país, pero tampoco es **gratuito** en tu país todavía, ¡házmelo saber y haré que Mac Mouse Fix sea gratuito en tu país también!

## 3. ¡Un buen momento para empezar a traducir!

Con Beta 4, he **implementado todos los cambios de interfaz** que tenía planeados para Mac Mouse Fix 3. Así que no espero que haya más cambios importantes en la interfaz hasta que se lance Mac Mouse Fix 3.

Si has estado esperando porque esperabas que la interfaz aún cambiara, ¡**este es un buen momento** para empezar a **traducir** la aplicación a tu idioma!

Para **más información** sobre la traducción de la aplicación, consulta **[Notas de la versión 3.0.0 Beta 1](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-1.1) > 9. Internacionalización**

## 4. Todo lo demás

Además de los cambios mencionados anteriormente, Beta 4 incluye muchas más **correcciones de errores**, **ajustes** y **mejoras de calidad de vida**:

### Interfaz de usuario

#### Correcciones de errores

- Corregido un error donde los enlaces de la pestaña Acerca de se abrían una y otra vez al hacer clic en cualquier parte de la ventana. ¡Créditos al usuario de GitHub [DingoBits](https://github.com/DingoBits) que lo arregló!
- Corregido algunos símbolos en la aplicación que no se mostraban correctamente en versiones antiguas de macOS
- Ocultas las barras de desplazamiento en la Tabla de Acciones. ¡Gracias al usuario de GitHub [marianmelinte93](https://github.com/marianmelinte93) que me hizo consciente de este problema en [este comentario](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366#discussioncomment-3728994)!
- Corregido un problema donde la retroalimentación sobre las funciones que se reactivan automáticamente cuando abres la pestaña respectiva para esa función en la interfaz (después de haber desactivado esa función desde la barra de menú) no se mostraba en macOS Monterey y versiones anteriores. Gracias de nuevo a [marianmelinte93](https://github.com/marianmelinte93) por hacerme consciente del problema.
- Añadida localización faltante y traducciones al alemán para la opción "Click to Scroll to Move Between Spaces"
- Corregidos más pequeños problemas de localización
- Añadidas más traducciones al alemán faltantes
- Las notificaciones que se muestran cuando se captura un botón / ya no se captura ahora funcionan correctamente cuando algunos botones han sido capturados y otros han sido descapturados al mismo tiempo.

#### Mejoras

- Eliminada la opción "Click and Scroll for App Switcher". Tenía algunos errores y no creo que fuera muy útil.
- Añadida la opción "Click and Scroll to Rotate".
- Ajustado el diseño del menú "Mac Mouse Fix" en la barra de menú.
- Añadido el botón "Comprar Mac Mouse Fix" al menú "Mac Mouse Fix" en la barra de menú.
- Añadido un texto de ayuda debajo de la opción "Mostrar en la barra de menú". El objetivo es hacer más visible que el elemento de la barra de menú puede usarse para activar o desactivar funciones rápidamente
- Los mensajes "Gracias por comprar Mac Mouse Fix" en la pantalla de acerca de ahora pueden ser completamente personalizados por los traductores.
- Mejoradas las pistas para los traductores
- Mejorados los textos de la interfaz relacionados con la expiración de la prueba
- Mejorados los textos de la interfaz en la pestaña Acerca de
- Añadidos resaltados en negrita a algunos textos de la interfaz para mejorar la legibilidad
- Añadida alerta al hacer clic en el enlace "Enviarme un correo electrónico" en la pestaña Acerca de.
- Cambiado el orden de clasificación de la Tabla de Acciones. Las acciones de Clic y Desplazamiento ahora se mostrarán antes que las acciones de Clic y Arrastrar. Esto me parece más natural porque las filas de la tabla ahora están ordenadas por la potencia de sus disparadores (Clic < Desplazamiento < Arrastrar).
- La aplicación ahora actualizará el dispositivo activamente utilizado al interactuar con la interfaz. Esto es útil porque parte de la interfaz ahora se basa en el dispositivo que estás usando. (Ver la nueva función "Restaurar valores predeterminados...")
- Ahora se muestra una notificación que indica qué botones han sido capturados / ya no están capturados cuando inicias la aplicación por primera vez.
- Más mejoras en las notificaciones que se muestran cuando un botón ha sido capturado / ya no está capturado
- Se ha hecho imposible introducir accidentalmente espacios en blanco adicionales al activar una clave de licencia

### Ratón

#### Correcciones de errores

- Mejorada la simulación de desplazamiento para enviar correctamente "deltas de punto fijo". Esto resuelve un problema donde la velocidad de desplazamiento era demasiado lenta en algunas aplicaciones como Safari con el desplazamiento suave desactivado.
- Corregido un problema donde la función "Click and Drag for Mission Control & Spaces" se quedaba atascada a veces cuando el ordenador estaba lento
- Corregido un problema donde la CPU siempre era utilizada por Mac Mouse Fix al mover el ratón después de haber usado la función "Click and Drag to Scroll & Navigate"

#### Mejoras

- Mejorada enormemente la capacidad de respuesta del zoom con desplazamiento en navegadores basados en Chromium como Chrome, Brave o Edge

### Bajo el capó

#### Correcciones de errores

- Corregido un problema donde Mac Mouse Fix no funcionaba correctamente después de moverlo a una carpeta diferente mientras estaba activado
- Corregidos algunos problemas con la activación de Mac Mouse Fix mientras otra instancia de Mac Mouse Fix todavía estaba activada. (Esto es porque Apple me permitió cambiar el ID del paquete de "com.nuebling.mac-mouse-fixxx" que se usaba en Beta 3 de vuelta al original "com.nuebling.mac-mouse-fix". No estoy seguro por qué.)

#### Mejoras

- Esta y futuras betas mostrarán información de depuración más detallada
- Limpieza y mejoras bajo el capó. Eliminado código antiguo pre-10.13. Limpiados frameworks y dependencias. El código fuente es ahora más fácil de trabajar, más preparado para el futuro.