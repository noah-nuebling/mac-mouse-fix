Mac Mouse Fix **3.0.1** trae varias correcciones de errores y mejoras, ¡junto con un **nuevo idioma**!

### ¡Se agregó el vietnamita!

Mac Mouse Fix ahora está disponible en 🇻🇳 vietnamita. ¡Muchas gracias a @nghlt [en GitHub](https://GitHub.com/nghlt)!

### Correcciones de errores

- ¡Mac Mouse Fix ahora funciona correctamente con el **Cambio Rápido de Usuario**!
  - El Cambio Rápido de Usuario es cuando inicias sesión en una segunda cuenta de macOS sin cerrar la sesión de la primera cuenta.
  - Antes de esta actualización, el desplazamiento dejaba de funcionar después de un cambio rápido de usuario. Ahora todo debería funcionar correctamente.
- Se corrigió un pequeño error donde el diseño de la pestaña Botones era demasiado ancho después de iniciar Mac Mouse Fix por primera vez.
- Se mejoró la fiabilidad del campo '+' al agregar varias Acciones en sucesión rápida.
- Se corrigió un error poco común reportado por @V-Coba en el Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Otras mejoras

- **El desplazamiento se siente más receptivo** cuando se usa la configuración 'Suavidad: Regular'.
  - La velocidad de la animación ahora se vuelve más rápida a medida que mueves la rueda de desplazamiento más rápido. De esta manera, se siente más receptivo cuando te desplazas rápido mientras se mantiene igual de suave cuando te desplazas lentamente.

- Se hizo la **aceleración de la velocidad de desplazamiento** más estable y predecible.
- Se implementó un mecanismo para **mantener tu configuración** cuando actualizas a una nueva versión de Mac Mouse Fix.
  - Antes, Mac Mouse Fix restablecía toda tu configuración después de actualizar a una nueva versión si la estructura de la configuración cambiaba. Ahora, Mac Mouse Fix intentará actualizar la estructura de tu configuración y mantener tus preferencias.
  - Por ahora, esto solo funciona al actualizar de 3.0.0 a 3.0.1. Si estás actualizando desde una versión anterior a 3.0.0, o si _degradas_ de 3.0.1 _a_ una versión anterior, tu configuración se seguirá restableciendo.
- El diseño de la pestaña Botones ahora adapta mejor su ancho a diferentes idiomas.
- Mejoras en el [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) y otros documentos.
- Mejoras en los sistemas de localización. Los archivos de traducción ahora se limpian y analizan automáticamente en busca de posibles problemas. Hay una nueva [Guía de Localización](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) que presenta cualquier problema detectado automáticamente junto con otra información útil e instrucciones para personas que quieren ayudar a traducir Mac Mouse Fix. Se eliminó la dependencia de la herramienta [BartyCrouch](https://github.com/FlineDev/BartyCrouch) que se usaba anteriormente para obtener parte de esta funcionalidad.
- Se mejoraron varios textos de la interfaz en inglés y alemán.
- Muchas mejoras y limpieza bajo el capó.

---

¡También consulta las notas de la versión [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - la actualización más grande de Mac Mouse Fix hasta ahora!