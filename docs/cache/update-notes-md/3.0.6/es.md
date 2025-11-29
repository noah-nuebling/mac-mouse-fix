Mac Mouse Fix **3.0.6** hace que la función de 'Atrás' y 'Adelante' sea compatible con más aplicaciones.
También soluciona varios errores y problemas.

### Función de 'Atrás' y 'Adelante' mejorada

Las asignaciones de los botones del ratón 'Atrás' y 'Adelante' ahora **funcionan en más aplicaciones**, incluyendo:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed y otros editores de código
- Muchas aplicaciones integradas de Apple como Vista Previa, Notas, Configuración del Sistema, App Store y Música
- Adobe Acrobat
- Zotero
- ¡Y más!

La implementación está inspirada en la excelente función 'Universal Back and Forward' de [LinearMouse](https://github.com/linearmouse/linearmouse). Debería ser compatible con todas las aplicaciones que LinearMouse soporta. \
Además, es compatible con algunas aplicaciones que normalmente requieren atajos de teclado para ir atrás y adelante, como Configuración del Sistema, App Store, Notas de Apple y Adobe Acrobat. Mac Mouse Fix ahora detectará esas aplicaciones y simulará los atajos de teclado apropiados.

¡Todas las aplicaciones que alguna vez se han [solicitado en un Issue de GitHub](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) deberían estar soportadas ahora! (¡Gracias por los comentarios!) \
Si encuentras alguna aplicación que aún no funcione, házmelo saber en una [solicitud de función](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Solucionando el error de 'El desplazamiento deja de funcionar intermitentemente'

Algunos usuarios experimentaron un [problema](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) donde **el desplazamiento suave deja de funcionar** aleatoriamente.

Aunque nunca he podido reproducir el problema, he implementado una posible solución:

La aplicación ahora reintentará varias veces cuando falle la configuración de la sincronización con la pantalla. \
Si aún no funciona después de reintentar, la aplicación:

- Reiniciará el proceso en segundo plano 'Mac Mouse Fix Helper', lo que puede resolver el problema
- Producirá un informe de error, que puede ayudar a diagnosticar el fallo

¡Espero que el problema esté resuelto ahora! Si no, házmelo saber en un [reporte de error](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) o por [correo electrónico](http://redirect.macmousefix.com/?target=mailto-noah).



### Comportamiento mejorado de la rueda de desplazamiento de giro libre

Mac Mouse Fix **ya no acelerará el desplazamiento** cuando dejes que la rueda de desplazamiento gire libremente en el ratón MX Master. (O cualquier otro ratón con una rueda de desplazamiento de giro libre.)

Aunque esta función de 'aceleración del desplazamiento' es útil en ruedas de desplazamiento normales, en una rueda de desplazamiento de giro libre puede hacer que las cosas sean más difíciles de controlar.

**Nota:** Mac Mouse Fix actualmente no es totalmente compatible con la mayoría de los ratones Logitech, incluyendo el MX Master. Planeo añadir compatibilidad completa, pero probablemente llevará un tiempo. Mientras tanto, el mejor controlador de terceros con soporte para Logitech que conozco es [SteerMouse](https://plentycom.jp/en/steermouse/).





### Correcciones de errores

- Se corrigió un problema donde Mac Mouse Fix a veces volvía a habilitar atajos de teclado que habían sido deshabilitados previamente en Configuración del Sistema
- Se corrigió un error al hacer clic en 'Activar Licencia'
- Se corrigió un error al hacer clic en 'Cancelar' justo después de hacer clic en 'Activar Licencia' (¡Gracias por el reporte, Ali!)
- Se corrigieron errores al intentar usar Mac Mouse Fix sin ninguna pantalla conectada a tu Mac
- Se corrigió una fuga de memoria y algunos otros problemas internos al cambiar entre pestañas en la aplicación

### Mejoras visuales

- Se corrigió un problema donde la pestaña Acerca de a veces era demasiado alta, que se introdujo en [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- El texto en la notificación 'Se acabaron los días gratis' ya no se corta en chino
- Se corrigió un fallo visual en la sombra del campo '+' después de grabar una entrada
- Se corrigió un fallo raro donde el texto de marcador de posición en la pantalla 'Ingresa tu clave de licencia' aparecía descentrado
- Se corrigió un problema donde algunos símbolos mostrados en la aplicación tenían el color incorrecto después de cambiar entre modo oscuro/claro

### Otras mejoras

- Se hicieron algunas animaciones, como la animación de cambio de pestaña, ligeramente más eficientes
- Se deshabilitó el autocompletado de texto de la Touch Bar en la pantalla 'Ingresa tu clave de licencia'
- Varias mejoras menores internas

*Editado con excelente asistencia de Claude.*

---

También echa un vistazo a la versión anterior [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).