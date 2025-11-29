Mac Mouse Fix **3.0.8** soluciona problemas de interfaz y más.

### **Problemas de interfaz**

- Se desactivó el nuevo diseño en macOS 26 Tahoe. Ahora la app se verá y funcionará como lo hacía en macOS 15 Sequoia.
    - Hice esto porque algunos de los elementos de interfaz rediseñados por Apple todavía tienen problemas. Por ejemplo, los botones '-' en la pestaña 'Botones' no siempre eran clicables.
    - La interfaz puede verse un poco anticuada en macOS 26 Tahoe ahora. Pero debería ser completamente funcional y pulida como antes.
- Se corrigió un error donde la notificación 'Se acabaron los días gratis' se quedaba atascada en la esquina superior derecha de la pantalla.
    - ¡Gracias a [Sashpuri](https://github.com/Sashpuri) y otros por reportarlo!

### **Pulido de interfaz**

- Se desactivó el botón de semáforo verde en la ventana principal de Mac Mouse Fix.
    - El botón no hacía nada, ya que la ventana no puede redimensionarse manualmente.
- Se corrigió un problema donde algunas de las líneas horizontales en la tabla de la pestaña 'Botones' eran demasiado oscuras en macOS 26 Tahoe.
- Se corrigió un error donde el mensaje "No se puede usar el botón principal del ratón" en la pestaña 'Botones' a veces se cortaba en macOS 26 Tahoe.
- Se corrigió un error tipográfico en la interfaz en alemán. Cortesía del usuario de GitHub [i-am-the-slime](https://github.com/i-am-the-slime). ¡Gracias!
- Se solucionó un problema donde la ventana de MMF a veces parpadeaba brevemente con el tamaño incorrecto al abrir la ventana en macOS 26 Tahoe.

### **Otros cambios**

- Se mejoró el comportamiento al intentar habilitar Mac Mouse Fix mientras múltiples instancias de Mac Mouse Fix están ejecutándose en la computadora.
    - Mac Mouse Fix ahora intentará desactivar la otra instancia de Mac Mouse Fix con más diligencia.
    - Esto puede mejorar casos extremos donde Mac Mouse Fix no podía habilitarse.
- Cambios y limpieza internos.

---

También revisa las novedades de la versión anterior [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).