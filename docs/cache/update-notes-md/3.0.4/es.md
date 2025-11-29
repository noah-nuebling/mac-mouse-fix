Mac Mouse Fix **3.0.4** mejora la privacidad, eficiencia y fiabilidad.\
Introduce un nuevo sistema de licencias sin conexión y corrige varios errores importantes.

### Privacidad y Eficiencia Mejoradas

3.0.4 introduce un nuevo sistema de validación de licencias sin conexión que minimiza las conexiones a internet tanto como sea posible.\
Esto mejora la privacidad y ahorra recursos del sistema de tu ordenador.\
Cuando está licenciada, ¡la aplicación ahora funciona 100% sin conexión!

<details>
<summary><b>Haz clic aquí para más detalles</b></summary>
Las versiones anteriores validaban las licencias en línea en cada inicio, lo que potencialmente permitía que los registros de conexión fueran almacenados por servidores de terceros (GitHub y Gumroad). El nuevo sistema elimina las conexiones innecesarias: después de la activación inicial de la licencia, solo se conecta a internet si los datos locales de la licencia están corruptos.
<br><br>
Aunque nunca registré personalmente ningún comportamiento de usuario, el sistema anterior teóricamente permitía que servidores de terceros registraran direcciones IP y horarios de conexión. Gumroad también podía registrar tu clave de licencia y potencialmente correlacionarla con cualquier información personal que hubieran registrado sobre ti cuando compraste Mac Mouse Fix.
<br><br>
No consideré estos sutiles problemas de privacidad cuando construí el sistema de licencias original, pero ahora, ¡Mac Mouse Fix es tan privado y libre de internet como sea posible!
<br><br>
Consulta también la <a href=https://gumroad.com/privacy>política de privacidad de Gumroad</a> y este <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>comentario de GitHub</a> mío.

</details>

### Corrección de Errores

- Corregido un error donde macOS a veces se quedaba bloqueado al usar 'Clic y Arrastrar' para 'Spaces y Mission Control'.
- Corregido un error donde los atajos de teclado en Ajustes del Sistema a veces se eliminaban al usar acciones de 'Clic' de Mac Mouse Fix como 'Mission Control'.
- Corregido [un error](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) donde la aplicación a veces dejaba de funcionar y mostraba una notificación de que los 'Días gratuitos han terminado' a usuarios que ya habían comprado la aplicación.
    - Si experimentaste este error, te pido sinceras disculpas por las molestias. Puedes solicitar un [reembolso aquí](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Mejorada la forma en que la aplicación recupera su ventana principal, lo que puede haber corregido un error donde la pantalla 'Activar Licencia' a veces no aparecía.

### Mejoras de Usabilidad

- Se ha hecho imposible introducir espacios y saltos de línea en el campo de texto de la pantalla 'Activar Licencia'.
    - Esto era un punto común de confusión, porque es muy fácil seleccionar accidentalmente un salto de línea oculto al copiar tu clave de licencia de los correos de Gumroad.
- Estas notas de actualización se traducen automáticamente para usuarios que no hablan inglés (Con tecnología de Claude). ¡Espero que sea útil! Si encuentras algún problema con esto, házmelo saber. Este es un primer vistazo a un nuevo sistema de traducción que he estado desarrollando durante el último año.

### Soporte Eliminado (No Oficial) para macOS 10.14 Mojave

Mac Mouse Fix 3 oficialmente soporta macOS 11 Big Sur y posteriores. Sin embargo, para usuarios dispuestos a aceptar algunos fallos y problemas gráficos, Mac Mouse Fix 3.0.3 y versiones anteriores aún podían usarse en macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 elimina ese soporte y **ahora requiere macOS 10.15 Catalina**. \
Me disculpo por cualquier inconveniente causado por esto. Este cambio me permitió implementar el sistema de licencias mejorado usando características modernas de Swift. Los usuarios de Mojave pueden continuar usando Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) o la [última versión de Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Espero que sea una buena solución para todos.

### Mejoras Internas

- Implementado un nuevo sistema 'MFDataClass' que permite un modelado de datos más potente mientras mantiene el archivo de configuración de Mac Mouse Fix legible y editable por humanos.
- Construido soporte para añadir plataformas de pago distintas a Gumroad. Así que en el futuro, podría haber pagos localizados, y la aplicación podría venderse en diferentes países.
- Mejorado el registro que me permite crear "Compilaciones de Depuración" más efectivas para usuarios que experimentan errores difíciles de reproducir.
- Muchas otras pequeñas mejoras y trabajo de limpieza.

*Editado con excelente asistencia de Claude.*

---

También echa un vistazo a la versión anterior [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).