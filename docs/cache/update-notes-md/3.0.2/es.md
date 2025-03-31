Mac Mouse Fix **3.0.2** trae varias mejoras, incluyendo **desplazamiento más suave**, traducciones mejoradas, ¡y más!

### Desplazamiento

- Ahora puedes detener las animaciones de desplazamiento moviendo un paso en la dirección opuesta. Esto te permite **'lanzar'** y **'atrapar la página'** cuando usas 'Suavidad: Alta', similar a un trackpad.
- Mac Mouse Fix ahora envía eventos de desplazamiento más temprano en el ciclo de actualización de la pantalla, dando más tiempo a las aplicaciones para procesar los eventos y mostrar el desplazamiento suavemente. Esto **mejora la tasa de fotogramas**, especialmente en sitios web complejos como YouTube.com.
- Mejorada la capacidad de respuesta del ajuste 'Suavidad: Alta', haciendo el desplazamiento más fácil de controlar.
- Mejorado el mecanismo introducido en 3.0.1 donde la velocidad de animación se vuelve más rápida conforme mueves la rueda del ratón más rápido usando 'Suavidad: Regular'. En 3.0.2, la aceleración de la animación debería aparecer más consistente y predecible, haciéndola más agradable a la vista mientras proporciona un gran control.
- Corregido un problema donde la velocidad de desplazamiento era demasiado lenta, especialmente al usar la opción 'Precisión'. Este problema fue introducido en 3.0.1. Gracias a @V-Coba por señalarlo en [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- Mejorado el comportamiento dentro del navegador Arc cuando se usa 'Clic y Desplazamiento' para 'Acercar o Alejar'.

### Localización

- Actualizadas las traducciones al 🇻🇳 vietnamita. ¡Créditos a @nghlt!
- Mejoradas algunas traducciones al 🇩🇪 alemán.
- El texto dentro de Mac Mouse Fix que no tiene traducción para el idioma actual ahora mostrará un valor provisional en lugar de quedar en blanco. Esto debería hacer menos confusa la navegación por la aplicación cuando faltan traducciones.

### Otros

- Mac Mouse Fix ahora mostrará una notificación con un enlace a [esta guía](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) para usuarios que podrían estar experimentando un error en macOS 13 Ventura y posteriores que puede impedir que Mac Mouse Fix se active.
- Cambiada la configuración predeterminada para ratones con 3 botones. La configuración predeterminada ya no incluye una acción de 'Clic y Desplazamiento' para el botón de la rueda de desplazamiento, ya que es bastante difícil de realizar. En su lugar, la configuración predeterminada ahora incluye una acción de 'Mantener' y 'Doble Clic'.
- Añadido un tooltip al icono de Mac Mouse Fix en la pestaña Acerca de. Te indica cómo revelar el archivo de configuración de Mac Mouse Fix en el Finder.
- Muchas mejoras y limpieza bajo el capó.

---

También echa un vistazo a la versión anterior [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).