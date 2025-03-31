Mac Mouse Fix **3.0.4 Beta 1** mejora la privacidad, eficiencia y fiabilidad.\
Introduce un nuevo sistema de licencias sin conexión y corrige varios errores importantes.

### Mejoras en Privacidad y Eficiencia

- Introduce un nuevo sistema de validación de licencias sin conexión que minimiza las conexiones a internet.
- La aplicación ahora solo se conecta a internet cuando es absolutamente necesario, protegiendo tu privacidad y reduciendo el uso de recursos.
- La aplicación funciona completamente sin conexión durante el uso normal cuando está licenciada.

<details>
<summary><b>Información Detallada sobre Privacidad</b></summary>
Las versiones anteriores validaban las licencias en línea en cada inicio, permitiendo potencialmente que los registros de conexión se almacenaran en servidores de terceros (GitHub y Gumroad). El nuevo sistema elimina las conexiones innecesarias – después de la activación inicial de la licencia, solo se conecta a internet si los datos locales de la licencia están dañados.
<br><br>
Si bien yo nunca registré el comportamiento del usuario personalmente, el sistema anterior teóricamente permitía que los servidores de terceros registraran direcciones IP y tiempos de conexión. Gumroad también podía registrar tu clave de licencia y potencialmente correlacionarla con cualquier información personal que hubieran registrado sobre ti cuando compraste Mac Mouse Fix.
<br><br>
No consideré estos sutiles problemas de privacidad cuando construí el sistema de licencias original, pero ahora, ¡Mac Mouse Fix es tan privado y libre de internet como es posible!
<br><br>
Consulta también la <a href=https://gumroad.com/privacy>política de privacidad de Gumroad</a> y este <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>comentario mío en GitHub</a>.

</details>

### Corrección de Errores

- Se corrigió un error donde macOS a veces se quedaba bloqueado al usar 'Click and Drag' para 'Spaces & Mission Control'.
- Se corrigió un error donde los atajos de teclado en Ajustes del Sistema a veces se eliminaban al usar una acción de 'Click' definida en Mac Mouse Fix como 'Mission Control'.
- Se corrigió [un error](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) donde la aplicación a veces dejaba de funcionar y mostraba una notificación de que los 'días gratuitos se acabaron' a usuarios que ya habían comprado la aplicación.
    - Si experimentaste este error, me disculpo sinceramente por las molestias. Puedes solicitar un [reembolso aquí](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).

### Mejoras Técnicas

- Se implementó un nuevo sistema 'MFDataClass' que permite un modelado de datos más limpio y archivos de configuración legibles por humanos.
- Se construyó soporte para agregar plataformas de pago además de Gumroad. ¡Así que en el futuro, podría haber pagos localizados y la aplicación podría venderse en diferentes países!

### Se Eliminó el Soporte (No Oficial) para macOS 10.14 Mojave

Mac Mouse Fix 3 oficialmente soporta macOS 11 Big Sur y versiones posteriores. Sin embargo, para usuarios dispuestos a aceptar algunos fallos y problemas gráficos, Mac Mouse Fix 3.0.3 y anteriores aún podían usarse en macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 elimina ese soporte y **ahora requiere macOS 10.15 Catalina**.\
Me disculpo por cualquier inconveniente causado por esto. Este cambio me permitió implementar el sistema de licencias mejorado usando características modernas de Swift. Los usuarios de Mojave pueden continuar usando Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) o la [última versión de Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Espero que esta sea una buena solución para todos.

*Editado con la excelente asistencia de Claude.*

---

También revisa la versión anterior [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).