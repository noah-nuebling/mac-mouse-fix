Mac Mouse Fix **3.0.7** soluciona varios errores importantes.

### Corrección de errores

- La app vuelve a funcionar en **versiones antiguas de macOS** (macOS 10.15 Catalina y macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 no podía habilitarse en esas versiones de macOS porque la función mejorada de 'Atrás' y 'Adelante' introducida en Mac Mouse Fix 3.0.6 intentaba usar APIs del sistema de macOS que no estaban disponibles.
- Se corrigieron problemas con la función de **'Atrás' y 'Adelante'**
    - La función mejorada de 'Atrás' y 'Adelante' introducida en Mac Mouse Fix 3.0.6 ahora siempre usará el 'hilo principal' para preguntarle a macOS qué teclas simular para ir atrás y adelante en la app que estés usando. \
    Esto puede prevenir fallos y comportamiento poco fiable en algunas situaciones.
- Se intentó corregir el error donde **la configuración se reiniciaba aleatoriamente** (Ver estos [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Reescribí el código que carga el archivo de configuración de Mac Mouse Fix para que sea más robusto. Cuando ocurrían errores raros del sistema de archivos de macOS, el código antiguo a veces podía pensar erróneamente que el archivo de configuración estaba corrupto y lo reiniciaba a los valores predeterminados.
- Se redujeron las probabilidades de un error donde **el desplazamiento deja de funcionar**     
     - Este error no puede solucionarse completamente sin cambios más profundos, que probablemente causarían otros problemas. \
      Sin embargo, por el momento, reduje la ventana de tiempo donde puede ocurrir un 'bloqueo mutuo' en el sistema de desplazamiento, lo que al menos debería reducir las probabilidades de encontrar este error. Esto también hace que el desplazamiento sea ligeramente más eficiente. 
    - Este error tiene síntomas similares – pero creo que una razón subyacente diferente – al error 'El desplazamiento deja de funcionar intermitentemente' que se abordó en la última versión 3.0.6.
    - (¡Gracias a Joonas por el diagnóstico!) 

¡Gracias a todos por reportar los errores! 

---

También echa un vistazo a la versión anterior [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).