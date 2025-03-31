Mac Mouse Fix **2.2.1** ofrece **soporte completo para macOS Ventura** entre otros cambios.

### ¡Soporte para Ventura!
Mac Mouse Fix ahora es totalmente compatible y se integra de forma nativa con macOS 13 Ventura.
Agradecimientos especiales a [@chamburr](https://github.com/chamburr) quien ayudó con el soporte para Ventura en el Issue de GitHub [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Los cambios incluyen:

- Actualización de la interfaz para otorgar Acceso de Accesibilidad para reflejar la nueva Configuración del Sistema de Ventura
- Mac Mouse Fix se mostrará correctamente en el nuevo menú **Configuración del Sistema > Elementos de Inicio** de Ventura
- Mac Mouse Fix reaccionará adecuadamente cuando se desactive en **Configuración del Sistema > Elementos de Inicio**

### Se eliminó el soporte para versiones anteriores de macOS

Desafortunadamente, Apple solo permite desarrollar _para_ macOS 10.13 **High Sierra y posteriores** cuando se desarrolla _desde_ macOS 13 Ventura.

Por lo tanto, la **versión mínima compatible** ha aumentado de 10.11 El Capitan a 10.13 High Sierra.

### Corrección de errores

- Se corrigió un problema donde Mac Mouse Fix cambiaba el comportamiento del desplazamiento de algunas **tabletas de dibujo**. Ver Issue de GitHub [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Se corrigió un problema donde los **atajos de teclado** que incluían la tecla 'A' no podían ser registrados. Corrige el Issue de GitHub [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Se corrigió un problema donde algunas **reasignaciones de botones** no funcionaban correctamente al usar una distribución de teclado no estándar.
- Se corrigió un fallo en '**Ajustes específicos por app**' al intentar añadir una app sin 'Bundle ID'. Podría ayudar con el Issue de GitHub [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Se corrigió un fallo al intentar añadir apps sin nombre a '**Ajustes específicos por app**'. Resuelve el Issue de GitHub [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). ¡Agradecimientos especiales a [jeongtae](https://github.com/jeongtae) quien fue de gran ayuda para identificar el problema!
- Más correcciones de errores menores y mejoras internas.