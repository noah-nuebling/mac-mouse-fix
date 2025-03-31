**ℹ️ Nota para usuarios de Mac Mouse Fix 2**

Con la introducción de Mac Mouse Fix 3, el modelo de precios de la aplicación ha cambiado:

- **Mac Mouse Fix 2**\
Permanece 100% gratuito, y planeo seguir dando soporte.\
**Omite esta actualización** para seguir usando Mac Mouse Fix 2. Descarga la última versión de Mac Mouse Fix 2 [aquí](https://redirect.macmousefix.com/?target=mmf2-latest).
- **Mac Mouse Fix 3**\
Gratis durante 30 días, cuesta unos pocos dólares para tenerlo en propiedad.\
**¡Actualiza ahora** para obtener Mac Mouse Fix 3!

Puedes aprender más sobre los precios y características de Mac Mouse Fix 3 en el [nuevo sitio web](https://macmousefix.com/).

¡Gracias por usar Mac Mouse Fix! :)

---

**ℹ️ Nota para compradores de Mac Mouse Fix 3**

Si actualizaste accidentalmente a Mac Mouse Fix 3 sin saber que ya no es gratuito, me gustaría ofrecerte un [reembolso](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

La última versión de Mac Mouse Fix 2 sigue siendo **completamente gratuita**, y puedes descargarla [aquí](https://redirect.macmousefix.com/?target=mmf2-latest).

¡Lamento las molestias y espero que todos estén de acuerdo con esta solución!

---

Mac Mouse Fix **3.0.3** está listo para macOS 15 Sequoia. También corrige algunos problemas de estabilidad y proporciona varias pequeñas mejoras.

### Soporte para macOS 15 Sequoia

¡La aplicación ahora funciona correctamente en macOS 15 Sequoia!

- La mayoría de las animaciones de la interfaz estaban rotas en macOS 15 Sequoia. ¡Ahora todo funciona correctamente de nuevo!
- El código fuente ahora se puede compilar en macOS 15 Sequoia. Antes, había problemas con el compilador Swift que impedían la compilación de la aplicación.

### Solución a los bloqueos durante el desplazamiento

Desde Mac Mouse Fix 3.0.2 hubo [múltiples reportes](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) de Mac Mouse Fix desactivándose y reactivándose periódicamente durante el desplazamiento. Esto fue causado por bloqueos de la aplicación de fondo 'Mac Mouse Fix Helper'. Esta actualización intenta corregir estos bloqueos con los siguientes cambios:

- El mecanismo de desplazamiento intentará recuperarse y seguir funcionando en lugar de bloquearse cuando encuentre el caso extremo que parece haber provocado estos bloqueos.
- He cambiado la forma en que se manejan los estados inesperados en la aplicación en general: En lugar de bloquearse inmediatamente, la aplicación ahora intentará recuperarse de estados inesperados en muchos casos.

    - Este cambio contribuye a las correcciones de los bloqueos de desplazamiento descritos anteriormente. También podría prevenir otros bloqueos.

Nota al margen: Nunca pude reproducir estos bloqueos en mi máquina y todavía no estoy seguro de qué los causó, pero según los informes que recibí, esta actualización debería prevenir cualquier bloqueo. Si aún experimentas bloqueos durante el desplazamiento o si experimentaste bloqueos en la versión 3.0.2, sería valioso que compartieras tu experiencia y datos de diagnóstico en el Issue de GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Esto me ayudaría a entender el problema y mejorar Mac Mouse Fix. ¡Gracias!

### Solución a los tartamudeos durante el desplazamiento

En la versión 3.0.2 hice cambios en la forma en que Mac Mouse Fix envía eventos de desplazamiento al sistema en un intento de reducir los tartamudeos probablemente causados por problemas con las APIs de VSync de Apple.

Sin embargo, después de pruebas más extensas y retroalimentación, parece que el nuevo mecanismo en 3.0.2 hace que el desplazamiento sea más suave en algunos escenarios pero más entrecortado en otros. Especialmente en Firefox parecía ser notablemente peor.\
En general, no estaba claro que el nuevo mecanismo realmente mejorara los tartamudeos en todos los casos. Además, podría haber contribuido a los bloqueos de desplazamiento descritos anteriormente.

Por eso he desactivado el nuevo mecanismo y he revertido el mecanismo de VSync para eventos de desplazamiento a como estaba en Mac Mouse Fix 3.0.0 y 3.0.1.

Consulta el Issue de GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) para más información.

### Reembolso

Lamento los problemas relacionados con los cambios en el desplazamiento en las versiones 3.0.1 y 3.0.2. Subestimé enormemente los problemas que surgirían con eso, y fui lento en abordar estos problemas. Haré todo lo posible por aprender de esta experiencia y ser más cuidadoso con tales cambios en el futuro. También me gustaría ofrecer un reembolso a cualquier persona afectada. Solo haz clic [aquí](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) si estás interesado.

### Mecanismo de actualización más inteligente

Estos cambios se trajeron de Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) y [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consulta sus notas de lanzamiento para conocer más detalles. Aquí hay un resumen:

- Hay un nuevo mecanismo más inteligente que decide qué actualización mostrar al usuario.
- Se cambió del marco de actualización Sparkle 1.26.0 al último Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- La ventana que muestra la aplicación para informarte que hay una nueva versión de Mac Mouse Fix disponible ahora admite JavaScript, lo que permite un mejor formato de las notas de actualización.

### Otras mejoras y correcciones de errores

- Se corrigió un problema donde el precio de la aplicación y la información relacionada se mostraban incorrectamente en la pestaña 'Acerca de' en algunos casos.
- Se corrigió un problema donde el mecanismo para sincronizar el desplazamiento suave con la tasa de refresco de la pantalla no funcionaba correctamente al usar múltiples pantallas.
- Muchas mejoras y limpiezas menores bajo el capó.

---

También consulta el lanzamiento anterior [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).