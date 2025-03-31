¡Echa un vistazo también a las **novedades** introducidas en [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

¡Mac Mouse Fix **2.2.0** incluye varias mejoras de usabilidad y correcciones de errores!

### La reasignación a teclas de función exclusivas de Apple ahora es mejor

La última actualización, 2.1.0, introdujo una nueva función que te permite reasignar los botones del ratón a cualquier tecla de tu teclado, incluso las teclas de función que solo se encuentran en teclados Apple. 2.2.0 presenta más mejoras y refinamientos en esta función:

- Ahora puedes mantener presionada la tecla Opción (⌥) para reasignar a teclas que solo se encuentran en teclados Apple, incluso si no tienes un teclado Apple a mano.
- Los símbolos de las teclas de función tienen una apariencia mejorada, integrándose mejor con el resto del texto.
- Se ha desactivado la capacidad de reasignar al Bloq Mayús. No funcionaba como se esperaba.

### Añade / elimina Acciones más fácilmente

Algunos usuarios tenían problemas para descubrir que se pueden añadir y eliminar Acciones de la Tabla de Acciones. Para hacer las cosas más fáciles de entender, 2.2.0 incluye los siguientes cambios y nuevas funciones:

- Ahora puedes eliminar Acciones haciendo clic derecho sobre ellas.
  - Esto debería hacer más fácil descubrir la opción de eliminar Acciones.
  - El menú del clic derecho muestra un símbolo del botón '-'. Esto debería ayudar a llamar la atención sobre el _botón_ '-', que a su vez debería llamar la atención sobre el botón '+'. Esto esperamos que haga la opción de **añadir** Acciones más visible también.
- Ahora puedes añadir Acciones a la Tabla de Acciones haciendo clic derecho en una fila vacía.
- El botón '-' ahora solo está activo cuando se selecciona una Acción. Esto debería dejar más claro que el botón '-' elimina la Acción seleccionada.
- La altura predeterminada de la ventana se ha aumentado para que haya una fila vacía visible que se pueda hacer clic derecho para añadir una Acción.
- Los botones '+' y '-' ahora tienen tooltips.

### Mejoras en Clic y Arrastrar

El umbral para activar Clic y Arrastrar se ha aumentado de 5 píxeles a 7 píxeles. Esto hace más difícil activar accidentalmente Clic y Arrastrar, mientras que aún permite a los usuarios cambiar de Espacios, etc. usando movimientos pequeños y cómodos.

### Otros cambios en la interfaz

- Se ha mejorado la apariencia de la Tabla de Acciones.
- Varias otras mejoras en la interfaz.

### Correcciones de errores

- Se corrigió un problema donde la interfaz no se atenuaba al iniciar MMF mientras estaba desactivado.
- Se eliminó la opción oculta "Botón 3 Clic y Arrastrar".
  - Al seleccionarla, la aplicación se cerraba. Construí esta opción para hacer Mac Mouse Fix más compatible con Blender. Pero en su forma actual, no es muy útil para los usuarios de Blender porque no se puede combinar con modificadores de teclado. Planeo mejorar la compatibilidad con Blender en una futura versión.