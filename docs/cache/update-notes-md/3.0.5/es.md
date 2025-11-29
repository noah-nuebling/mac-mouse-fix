Mac Mouse Fix **3.0.5** corrige varios errores, mejora el rendimiento y añade un toque de pulido a la aplicación. \
También es compatible con macOS 26 Tahoe.

### Simulación Mejorada del Desplazamiento del Trackpad

- El sistema de desplazamiento ahora puede simular un toque con dos dedos en el trackpad para hacer que las aplicaciones dejen de desplazarse.
    - Esto corrige un problema al ejecutar aplicaciones de iPhone o iPad, donde el desplazamiento a menudo continuaba después de que el usuario decidiera detenerlo.
- Se corrigió la simulación inconsistente de levantar los dedos del trackpad.
    - Esto podría haber causado un comportamiento subóptimo en algunas situaciones.



### Compatibilidad con macOS 26 Tahoe

Al ejecutar la Beta de macOS 26 Tahoe, la aplicación ahora es utilizable y la mayor parte de la interfaz funciona correctamente.



### Mejora del Rendimiento

Se mejoró el rendimiento del gesto de Clic y Arrastrar para "Desplazar y Navegar". \
En mis pruebas, ¡el uso de CPU se ha reducido en aproximadamente un 50%!

**Contexto**

Durante el gesto "Desplazar y Navegar", Mac Mouse Fix dibuja un cursor de ratón falso en una ventana transparente, mientras bloquea el cursor de ratón real en su lugar. Esto asegura que puedas seguir desplazando el elemento de la interfaz en el que comenzaste a desplazarte, sin importar cuánto muevas tu ratón.

La mejora del rendimiento se logró desactivando el manejo de eventos predeterminado de macOS en esta ventana transparente, que de todos modos no se utilizaba.





### Correcciones de Errores

- Ahora se ignoran los eventos de desplazamiento de las tabletas de dibujo Wacom.
    - Antes, Mac Mouse Fix causaba un desplazamiento errático en las tabletas Wacom, como reportó @frenchie1980 en el Issue de GitHub [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (¡Gracias!)
    
- Se corrigió un error donde el código de Swift Concurrency, que se introdujo como parte del nuevo sistema de licencias en Mac Mouse Fix 3.0.4, no se ejecutaba en el hilo correcto.
    - Esto causaba fallos en macOS Tahoe, y probablemente también causó otros errores esporádicos relacionados con las licencias.
- Se mejoró la robustez del código que decodifica las licencias sin conexión.
    - Esto soluciona un problema en las APIs de Apple que causaba que la validación de licencias sin conexión siempre fallara en mi Mac Mini Intel. Asumo que esto ocurría en todas las Macs Intel, y que fue la razón por la que el error "Se acabaron los días gratis" (que ya se abordó en 3.0.4) todavía ocurría para algunas personas, como reportó @toni20k5267 en el Issue de GitHub [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (¡Gracias!)
        - Si experimentaste el error "Se acabaron los días gratis", ¡lo siento mucho! Puedes obtener un reembolso [aquí](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Mejoras de Experiencia de Usuario

- Se desactivaron los diálogos que proporcionaban soluciones paso a paso para errores de macOS que impedían a los usuarios habilitar Mac Mouse Fix.
    - Estos problemas solo ocurrían en macOS 13 Ventura y 14 Sonoma. Ahora, estos diálogos solo aparecen en las versiones de macOS donde son relevantes. 
    - Los diálogos también son un poco más difíciles de activar: antes, a veces aparecían en situaciones donde no eran muy útiles.
    
- Se añadió un enlace "Activar Licencia" directamente en la notificación "Se acabaron los días gratis". 
    - ¡Esto hace que activar una licencia de Mac Mouse Fix sea aún más sencillo!

### Mejoras Visuales

- Se mejoró ligeramente el aspecto de la ventana "Actualización de Software". Ahora encaja mejor con macOS 26 Tahoe. 
    - Esto se logró personalizando el aspecto predeterminado del framework "Sparkle 1.27.3" que Mac Mouse Fix usa para gestionar las actualizaciones.
- Se corrigió un problema donde el texto en la parte inferior de la pestaña Acerca de a veces se cortaba en chino, haciendo la ventana un poco más ancha.
- Se corrigió que el texto en la parte inferior de la pestaña Acerca de estuviera ligeramente descentrado.
- Se corrigió un error que causaba que el espacio debajo de la opción "Atajo de Teclado..." en la pestaña Botones fuera demasiado pequeño. 

### Cambios Internos

- Se eliminó la dependencia del framework "SnapKit".
    - Esto reduce ligeramente el tamaño de la aplicación de 19.8 a 19.5 MB.
- Varias otras pequeñas mejoras en el código base.

*Editado con excelente asistencia de Claude.*

---

También echa un vistazo a la versión anterior [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).