¡Echa un vistazo también a los **interesantes cambios** introducidos en [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

**3.0.0 Beta 6** trae optimizaciones profundas y pulido, una renovación de la configuración del desplazamiento, traducciones al chino, ¡y más!

Aquí está todo lo nuevo:

## 1. Optimizaciones Profundas

Para esta Beta, dediqué mucho trabajo a obtener el máximo rendimiento de Mac Mouse Fix. Y ahora me complace anunciar que, cuando haces clic en un botón del ratón en la Beta 6, ¡es **2 veces** más rápido en comparación con la beta anterior! ¡Y el desplazamiento es incluso **4 veces** más rápido!

Con Beta 6, MMF también desactivará de manera inteligente partes de sí mismo para ahorrar CPU y batería tanto como sea posible.

Por ejemplo, cuando estás usando un ratón con 3 botones pero solo tienes configuradas acciones para botones que no están en tu ratón, como los botones 4 y 5, Mac Mouse Fix dejará de escuchar completamente la entrada de botones de tu ratón. ¡Esto significa 0% de uso de CPU cuando haces clic en un botón de tu ratón! O cuando la configuración de desplazamiento en MMF coincide con la del sistema, Mac Mouse Fix dejará de escuchar completamente la entrada de tu rueda de desplazamiento. ¡Esto significa 0% de uso de CPU cuando te desplazas! Pero si configuras la función Command (⌘)-Scroll para Zoom, Mac Mouse Fix comenzará a escuchar la entrada de tu rueda de desplazamiento, pero solo mientras mantengas presionada la tecla Command (⌘). Y así sucesivamente.
¡Así que es realmente inteligente y solo usará CPU cuando sea necesario!

Esto significa que MMF no es solo el controlador de ratón más potente, fácil de usar y pulido para Mac, ¡sino que también es uno de los más optimizados y eficientes, si no el que más!

## 2. Tamaño de App Reducido

¡Con 16 MB, Beta 6 es aproximadamente 2 veces más pequeña que Beta 5!

Esto es un efecto secundario de eliminar el soporte para versiones antiguas de macOS.

## 3. Eliminación del Soporte para Versiones Antiguas de macOS

Intenté arduamente hacer que MMF 3 funcionara correctamente en versiones de macOS anteriores a macOS 11 Big Sur. Pero la cantidad de trabajo para que se sintiera pulido resultó ser abrumadora, así que tuve que renunciar a eso.

En adelante, la versión más antigua oficialmente soportada será macOS 11 Big Sur.

La aplicación aún se abrirá en versiones anteriores, pero habrá problemas visuales y posiblemente otros. La aplicación ya no se abrirá en versiones de macOS anteriores a 10.14.4. Esto es lo que nos permite reducir el tamaño de la aplicación en 2 veces, ya que 10.14.4 es la versión más antigua de macOS que incluye bibliotecas Swift modernas (Ver "Swift ABI Stability"), lo que significa que esas bibliotecas Swift ya no tienen que estar contenidas en la aplicación.

## 4. Mejoras en el Desplazamiento

Beta 6 presenta muchas mejoras en la configuración y la interfaz de usuario de los nuevos sistemas de desplazamiento introducidos en MMF 3.

### Interfaz de Usuario

- Se simplificó y acortó considerablemente el texto de la interfaz de usuario en la pestaña Scroll. Se eliminaron la mayoría de las menciones de la palabra "Scroll" ya que está implícita por el contexto.
- Se rediseñó la configuración de suavidad del desplazamiento para que sea mucho más clara y permita algunas opciones adicionales. Ahora puedes elegir entre una "Suavidad" de "Desactivada", "Regular" o "Alta", reemplazando el antiguo interruptor "con Inercia". Creo que esto es mucho más claro y dejó espacio en la interfaz para la nueva opción "Simulación de Trackpad".
- Desactivar la nueva opción "Simulación de Trackpad" deshabilita el efecto de banda elástica durante el desplazamiento, también evita el desplazamiento entre páginas en Safari y otras aplicaciones, y más. Mucha gente se ha molestado por esto, especialmente aquellos con ruedas de desplazamiento de giro libre como las que se encuentran en algunos ratones Logitech como el MX Master, pero otros lo disfrutan, así que decidí convertirlo en una opción. Espero que la presentación de la función sea clara. Si tienes alguna sugerencia al respecto, házmelo saber.
- Se cambió la opción "Dirección Natural de Desplazamiento" a "Invertir Dirección de Desplazamiento". Esto significa que la configuración ahora invierte la dirección de desplazamiento del sistema y ya no es independiente de la dirección de desplazamiento del sistema. Si bien esto es posiblemente una experiencia de usuario ligeramente peor, esta nueva forma de hacer las cosas nos permite implementar algunas optimizaciones y hace más transparente para el usuario cómo desactivar completamente Mac Mouse Fix para el desplazamiento.
- Se mejoró la forma en que la configuración de desplazamiento interactúa con el desplazamiento modificado en muchos casos límite diferentes. Por ejemplo, la opción "Precisión" ya no se aplicará a la acción "Clic y Desplazamiento" para "Escritorio y Launchpad" ya que es un obstáculo aquí en lugar de ser útil.
- Se mejoró la velocidad de desplazamiento al usar "Clic y Desplazamiento" para "Escritorio y Launchpad" o "Acercar o Alejar" y otras funciones.
- Se eliminó el enlace no funcional a la configuración de velocidad de desplazamiento del sistema en la pestaña de desplazamiento que estaba presente en versiones de macOS anteriores a macOS 13.0 Ventura. No pude encontrar una manera de hacer funcionar el enlace y no es terriblemente importante.

### Sensación de Desplazamiento

- Se mejoró la curva de animación para "Suavidad Regular" (anteriormente accesible al desactivar "con Inercia"). Esto hace que las cosas se sientan más suaves y receptivas.
- Se mejoró la sensación de todas las configuraciones de velocidad de desplazamiento. La velocidad "Media" y la velocidad "Rápida" son más rápidas. Hay más separación entre las velocidades "Baja", "Media" y "Alta". La aceleración a medida que mueves la rueda de desplazamiento más rápido se siente más natural y cómoda cuando usas la opción "Precisión".
- La forma en que la velocidad de desplazamiento aumenta mientras sigues desplazándote en una dirección se sentirá más natural y gradual. Estoy usando nuevas curvas matemáticas para modelar la aceleración. La aceleración también será más difícil de activar accidentalmente.
- Ya no se aumenta la velocidad de desplazamiento cuando sigues desplazándote en una dirección mientras usas la velocidad de desplazamiento "macOS".
- Se restringió el tiempo de animación de desplazamiento a un máximo. Si la animación de desplazamiento naturalmente tomaría más tiempo, se acelerará para mantenerse por debajo del tiempo máximo. De esta manera, desplazarse hasta el borde de la página con una rueda de giro libre no hará que el contenido de la página se mueva fuera de la pantalla durante tanto tiempo. Esto no debería afectar el desplazamiento normal con una rueda que no gira libremente.
- Se mejoraron algunas interacciones alrededor del efecto de banda elástica al desplazarse hasta el borde de una página en Safari y otras aplicaciones.
- Se corrigió un problema donde "Clic y Desplazamiento" y otras funciones relacionadas con el desplazamiento no funcionaban correctamente después de actualizar desde una versión muy antigua del panel de preferencias de Mac Mouse Fix.
- Se corrigió un problema donde los desplazamientos de un solo píxel se enviaban con retraso al usar la velocidad de desplazamiento "macOS" junto con el desplazamiento suave.
- Se corrigió un error donde el desplazamiento seguía siendo muy rápido después de soltar el modificador de Desplazamiento Rápido. Otras mejoras en torno a cómo se transfiere la velocidad de desplazamiento de deslizamientos anteriores.
- Se mejoró la forma en que la velocidad de desplazamiento aumenta con tamaños de pantalla más grandes.

## 5. Notarización

A partir de 3.0.0 Beta 6, Mac Mouse Fix estará "Notarizado". Esto significa que no habrá más mensajes sobre que Mac Mouse Fix es potencialmente "Software Malicioso" al abrir la aplicación por primera vez.

Notarizar tu aplicación cuesta $100 por año. Siempre estuve en contra de esto, ya que se sentía hostil hacia el software gratuito y de código abierto como Mac Mouse Fix, y también se sentía como un paso peligroso hacia que Apple controle y bloquee el Mac como lo hace con iOS. Pero la falta de Notarización llevó a problemas bastante graves, incluyendo [varias situaciones](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) donde nadie podía usar la aplicación hasta que lanzara una nueva versión. Ya que Mac Mouse Fix será monetizado ahora, pensé que finalmente era apropiado Notarizar la aplicación para una experiencia de usuario más fácil y estable.

## 6. Traducciones al Chino

¡Mac Mouse Fix ahora está disponible en chino!
Más específicamente, está disponible en:

- Chino Tradicional
- Chino Simplificado
- Chino (Hong Kong)

Muchas gracias a @groverlynn por proporcionar todas estas traducciones, así como por actualizarlas durante las betas y comunicarse conmigo. Mira su pull request aquí: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Todo lo Demás

Además de los cambios mencionados anteriormente, Beta 6 también presenta muchas mejoras menores.

- Se eliminaron varias opciones de las Acciones "Clic", "Clic y Mantener" y "Clic y Desplazamiento" porque pensé que eran redundantes ya que la misma funcionalidad se puede lograr de otra manera y ya que esto limpia mucho los menús. Las volveré a incluir si la gente se queja. Así que si echas de menos esas opciones, por favor quéjate.
- La dirección de Clic y Arrastrar ahora coincidirá con la dirección de deslizamiento del trackpad incluso cuando "Desplazamiento natural" está desactivado en Configuración del Sistema > Trackpad. Antes, Clic y Arrastrar siempre se comportaba como deslizar en el trackpad con "Desplazamiento natural" activado.
- Se corrigió un problema donde los cursores desaparecían y luego reaparecían en otro lugar al usar una Acción de "Clic y Arrastrar" durante una grabación de pantalla o al usar el software DisplayLink.
- Se corrigió el centrado del "+" en el Campo "+" en la pestaña Botones
- Varias mejoras visuales en la pestaña botones. La paleta de colores del Campo "+" y la Tabla de Acciones ha sido rediseñada para verse correcta cuando se usa la opción "Permitir tinte de fondo de pantalla en ventanas" de macOS. Los bordes de la Tabla de Acciones ahora tienen un color transparente que se ve más dinámico y se ajusta a su entorno.
- Se hizo que cuando agregas muchas acciones a la tabla de acciones y la ventana de Mac Mouse Fix crece, crecerá exactamente tan grande como la pantalla (o como la pantalla menos el dock si no tienes habilitado el ocultamiento del dock) y luego se detendrá. Cuando agregues aún más acciones, la tabla de acciones comenzará a desplazarse.
- Esta Beta ahora admite un nuevo proceso de pago donde puedes comprar una licencia en dólares estadounidenses como se anuncia. Antes solo podías comprar una licencia en euros. Las antiguas licencias en euros seguirán siendo compatibles, por supuesto.
- Se corrigió un problema donde el desplazamiento con impulso a veces no se iniciaba al usar la función "Desplazar y Navegar".
- Cuando la ventana de Mac Mouse Fix se redimensiona durante un cambio de pestaña, ahora se reposicionará para no superponerse con el Dock
- Se corrigió el parpadeo en algunos elementos de la interfaz de usuario al cambiar de la pestaña Botones a otra pestaña
- Se mejoró la apariencia de la animación que el Campo "+" reproduce después de grabar una entrada. Especialmente en versiones de macOS anteriores a Ventura, donde la sombra del Campo "+" aparecería defectuosa durante la animación.
- Se deshabilitaron las notificaciones que enumeran varios botones que han sido capturados/ya no son capturados por Mac Mouse Fix que aparecerían al iniciar la aplicación por primera vez o al cargar un preset. Pensé que estos mensajes eran distractores y ligeramente abrumadores y no realmente útiles en esos contextos.
- Se rediseñó la Pantalla de Concesión de Accesibilidad. Ahora mostrará información sobre por qué Mac Mouse Fix necesita Acceso de Accesibilidad en línea en lugar de enlazar al sitio web y es un poco más clara y tiene un diseño más agradable visualmente.
- Se actualizó el enlace de Agradecimientos en la pestaña Acerca de.
- Se mejoraron los mensajes de error cuando Mac Mouse Fix no puede habilitarse porque hay otra versión presente en el sistema. El mensaje ahora se mostrará en una ventana de alerta flotante que siempre permanece encima de otras ventanas hasta que se descarte, en lugar de una Notificación Toast que desaparece al hacer clic en cualquier lugar. Esto debería facilitar el seguimiento de los pasos de solución sugeridos.
- Se corrigieron algunos problemas con el renderizado de markdown en versiones de macOS anteriores a Ventura. MMF ahora usará una solución de renderizado de markdown personalizada para todas las versiones de macOS, incluida Ventura. Antes estábamos usando una API del sistema introducida en Ventura pero eso llevó a inconsistencias. Markdown se usa para agregar enlaces y énfasis al texto en toda la interfaz de usuario.
- Se pulieron las interacciones alrededor de habilitar el acceso de accesibilidad.
- Se corrigió un problema donde la ventana de la aplicación a veces se abría sin mostrar ningún contenido hasta que cambiaras a una de las pestañas.
- Se corrigió un problema con el Campo "+" donde a veces no podías agregar una nueva acción aunque mostrara un efecto de hover indicando que puedes ingresar una acción.
- Se corrigió un bloqueo y varios otros problemas pequeños que a veces ocurrían al mover el puntero del ratón dentro del Campo "+".
- Se corrigió un problema donde un popover que aparece en la pestaña Botones cuando tu ratón no parece ajustarse a la configuración actual de botones a veces tendría todo el texto en negrita.
- Se actualizaron todas las menciones de la antigua licencia MIT a la nueva licencia MMF. Los nuevos archivos creados para el proyecto ahora contendrán un encabezado autogenerado que menciona la licencia MMF.
- Se hizo que cambiar a la pestaña Botones habilite MMF para Desplazamiento. De lo contrario, no podrías grabar gestos de Clic y Desplazamiento.
- Se corrigieron algunos problemas donde los nombres de los botones no se mostraban correctamente en la Tabla de Acciones en algunas situaciones.
- Se corrigió un error donde la sección de prueba en la pantalla Acerca de se vería defectuosa al abrir la aplicación y luego cambiar a la pestaña de prueba después de que la prueba expiró.
- Se corrigió un error donde el enlace Activar Licencia en la sección de prueba de la pestaña Acerca de a veces no reaccionaba a los clics.
- Se corrigió una fuga de memoria al usar la función "Clic y Arrastrar" para "Espacios y Mission Control".
- Se habilitó el tiempo de ejecución endurecido en la aplicación principal Mac Mouse Fix, mejorando la seguridad
- Mucha limpieza de código, reestructuración del proyecto
- Se corrigieron varios otros fallos
- Se corrigieron varias fugas de memoria
- Varios pequeños ajustes en las cadenas de texto de la interfaz de usuario
- Las renovaciones de varios sistemas internos también mejoraron la robustez y el comportamiento en casos límite

## 8. Cómo Puedes Ayudar

¡Puedes ayudar compartiendo tus **ideas**, **problemas** y **comentarios**!

El mejor lugar para compartir tus **ideas** y **problemas** es el [Asistente de Comentarios](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
El mejor lugar para dar **comentarios** rápidos no estructurados es la [Discusión de Comentarios](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

También puedes acceder a estos lugares desde dentro de la aplicación en la pestaña "**ⓘ Acerca de**".

**¡Gracias** por ayudar a hacer que Mac Mouse Fix sea lo mejor posible! 🙌:)