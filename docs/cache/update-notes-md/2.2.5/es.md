Mac Mouse Fix **2.2.5** incluye mejoras en el mecanismo de actualización y ¡está listo para macOS 15 Sequoia!

### Nuevo marco de actualización Sparkle

Mac Mouse Fix utiliza el marco de actualización [Sparkle](https://sparkle-project.org/) para ayudar a proporcionar una gran experiencia de actualización.

Con 2.2.5, Mac Mouse Fix cambia de Sparkle 1.26.0 a la última versión [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), que contiene correcciones de seguridad, mejoras de localización y más.

### Mecanismo de actualización más inteligente

Hay un nuevo mecanismo que decide qué actualización mostrar al usuario. El comportamiento cambió de las siguientes maneras:

1. Después de omitir una actualización **mayor** (como 2.2.5 -> 3.0.0), seguirás recibiendo notificaciones de nuevas actualizaciones **menores** (como 2.2.5 -> 2.2.6).
    - Esto te permite mantener fácilmente Mac Mouse Fix 2 mientras sigues recibiendo actualizaciones, como se discutió en el Issue de GitHub [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. En lugar de mostrar la actualización a la última versión, Mac Mouse Fix ahora te mostrará la actualización a la primera versión de la última versión mayor.
    - Ejemplo: Si estás usando MMF 2.2.5, y MMF 3.4.5 es la última versión, la aplicación ahora te mostrará la primera versión de MMF 3 (3.0.0), en lugar de la última versión (3.4.5). De esta manera, todos los usuarios de MMF 2.2.5 verán el registro de cambios de MMF 3.0.0 antes de cambiar a MMF 3.
    - Discusión:
        - La principal motivación detrás de esto es que, a principios de este año, muchos usuarios de MMF 2 actualizaron directamente de MMF 2 a MMF 3.0.1 o 3.0.2. Como nunca vieron el registro de cambios de 3.0.0, se perdieron la información sobre los cambios de precios entre MMF 2 y MMF 3 (MMF 3 ya no es 100% gratuito). Así que cuando MMF 3 de repente indicó que necesitaban pagar para seguir usando la aplicación, algunos estaban - comprensiblemente - un poco confundidos y molestos.
        - Desventaja: Si solo quieres actualizar a la última versión, ahora tendrás que actualizar dos veces en algunos casos. Esto es ligeramente ineficiente, pero aún debería tomar solo unos segundos. Y dado que esto hace que los cambios entre versiones mayores sean mucho más transparentes, creo que es un compromiso sensato.

### Soporte para macOS 15 Sequoia

Mac Mouse Fix 2.2.5 funcionará perfectamente en el nuevo macOS 15 Sequoia - al igual que lo hizo 2.2.4.

---

También echa un vistazo a la versión anterior [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Si tienes problemas para habilitar Mac Mouse Fix después de actualizar, consulta la [Guía 'Habilitando Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*