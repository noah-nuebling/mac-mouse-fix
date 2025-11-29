Mac Mouse Fix **3.0.3** está listo para macOS 15 Sequoia. También corrige algunos problemas de estabilidad y proporciona varias mejoras menores.

### Compatibilidad con macOS 15 Sequoia

¡La aplicación ahora funciona correctamente en macOS 15 Sequoia!

- La mayoría de las animaciones de la interfaz estaban rotas en macOS 15 Sequoia. ¡Ahora todo funciona correctamente de nuevo!
- El código fuente ahora se puede compilar en macOS 15 Sequoia. Antes, había problemas con el compilador de Swift que impedían la compilación de la aplicación.

### Solución de bloqueos al desplazarse

Desde Mac Mouse Fix 3.0.2 hubo [múltiples reportes](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) de que Mac Mouse Fix se desactivaba y reactivaba periódicamente mientras se desplazaba. Esto fue causado por bloqueos de la aplicación en segundo plano 'Mac Mouse Fix Helper'. Esta actualización intenta corregir estos bloqueos, con los siguientes cambios:

- El mecanismo de desplazamiento intentará recuperarse y seguir funcionando en lugar de bloquearse, cuando encuentre el caso extremo que parece haber causado estos bloqueos.
- Cambié la forma en que se manejan los estados inesperados en la aplicación de manera más general: En lugar de bloquearse siempre de inmediato, la aplicación ahora intentará recuperarse de estados inesperados en muchos casos.
    
    - Este cambio contribuye a las correcciones para los bloqueos de desplazamiento descritos anteriormente. También podría prevenir otros bloqueos.
  
Nota al margen: Nunca pude reproducir estos bloqueos en mi máquina, y todavía no estoy seguro de qué los causó, pero según los reportes que recibí, esta actualización debería prevenir cualquier bloqueo. Si aún experimentas bloqueos al desplazarte o si *experimentaste* bloqueos en 3.0.2, sería valioso que compartieras tu experiencia y datos de diagnóstico en el Issue de GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Esto me ayudaría a entender el problema y mejorar Mac Mouse Fix. ¡Gracias!

### Solución de tartamudeos al desplazarse

En 3.0.2 hice cambios en cómo Mac Mouse Fix envía eventos de desplazamiento al sistema en un intento de reducir los tartamudeos de desplazamiento probablemente causados por problemas con las APIs de VSync de Apple.

Sin embargo, después de pruebas más extensas y comentarios, parece que el nuevo mecanismo en 3.0.2 hace que el desplazamiento sea más suave en algunos escenarios pero más entrecortado en otros. Especialmente en Firefox parecía ser notablemente peor. \
En general, no estaba claro que el nuevo mecanismo realmente mejorara los tartamudeos de desplazamiento en todos los casos. Además, podría haber contribuido a los bloqueos de desplazamiento descritos anteriormente.

Por eso desactivé el nuevo mecanismo y revertí el mecanismo de VSync para eventos de desplazamiento a como estaba en Mac Mouse Fix 3.0.0 y 3.0.1.

Consulta el Issue de GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) para más información.

### Reembolso

Lamento los problemas relacionados con los cambios de desplazamiento en 3.0.1 y 3.0.2. Subestimé enormemente los problemas que vendrían con eso, y fui lento en abordar estos problemas. Haré mi mejor esfuerzo para aprender de esta experiencia y ser más cuidadoso con tales cambios en el futuro. También me gustaría ofrecer un reembolso a cualquier persona afectada. Solo haz clic [aquí](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) si estás interesado.

### Mecanismo de actualización más inteligente

Estos cambios se trasladaron desde Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) y [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consulta sus notas de lanzamiento para conocer más sobre los detalles. Aquí hay un resumen:

- Hay un nuevo mecanismo más inteligente que decide qué actualización mostrar al usuario.
- Se cambió del framework de actualización Sparkle 1.26.0 al último Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- La ventana que la aplicación muestra para informarte que hay una nueva versión de Mac Mouse Fix disponible ahora admite JavaScript, lo que permite un mejor formato de las notas de actualización.

### Otras mejoras y correcciones de errores

- Se corrigió un problema donde el precio de la aplicación y la información relacionada se mostraban incorrectamente en la pestaña 'Acerca de' en algunos casos.
- Se corrigió un problema donde el mecanismo para sincronizar el desplazamiento suave con la frecuencia de actualización de la pantalla no funcionaba correctamente al usar múltiples pantallas.
- Muchas mejoras y limpiezas menores bajo el capó.

---

También consulta el lanzamiento anterior [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).