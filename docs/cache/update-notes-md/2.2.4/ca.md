Mac Mouse Fix **2.2.4** ara està notaritzat! També inclou algunes correccions d'errors i altres millores.

### **Notarització**

Mac Mouse Fix 2.2.4 ara està 'notaritzat' per Apple. Això significa que ja no hi haurà més missatges sobre que Mac Mouse Fix és potencialment un 'Programari Maliciós' quan s'obri l'aplicació per primera vegada.

#### Antecedents

Notaritzar la teva aplicació costa 100$ a l'any. Sempre m'hi havia oposat, ja que semblava hostil cap al programari gratuït i de codi obert com Mac Mouse Fix, i també semblava un pas perillós cap a que Apple controlés i tanqués el Mac com fan amb els iPhones o iPads. Però la manca de notarització va portar a diferents problemes, incloent [dificultats per obrir l'aplicació](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) i fins i tot [diverses situacions](https://github.com/noah-nuebling/mac-mouse-fix/issues/95) on ningú podia utilitzar l'aplicació fins que no publiqués una nova versió.

Per a Mac Mouse Fix 3, vaig pensar que finalment era apropiat pagar els 100$ anuals per notaritzar l'aplicació, ja que Mac Mouse Fix 3 està monetitzat. ([Més informació](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Ara, Mac Mouse Fix 2 també rep la notarització, la qual cosa hauria de portar a una experiència d'usuari més fàcil i estable.

### **Correccions d'errors**

- S'ha corregit un problema on el cursor desapareixia i després reapareixia en una ubicació diferent quan s'utilitzava una acció de 'Clic i Arrossega' durant una gravació de pantalla o mentre s'utilitzava el programari [DisplayLink](https://www.synaptics.com/products/displaylink-graphics).
- S'ha corregit un problema amb l'activació de Mac Mouse Fix sota macOS 10.14 Mojave i possiblement versions més antigues de macOS també.
- S'ha millorat la gestió de la memòria, potencialment corregint una fallada de l'aplicació 'Mac Mouse Fix Helper', que ocorria en desconnectar un ratolí de l'ordinador. Vegeu la Discussió [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Altres Millores**

- La finestra que mostra l'aplicació per informar-te que hi ha disponible una nova versió de Mac Mouse Fix ara suporta JavaScript. Això permet que les notes d'actualització siguin més boniques i fàcils de llegir. Per exemple, les notes d'actualització ara poden mostrar [Alertes de Markdown](https://github.com/orgs/community/discussions/16925) i més.
- S'ha eliminat un enllaç a la pàgina https://macmousefix.com/about/ de la pantalla "Concedir Accés d'Accessibilitat a Mac Mouse Fix Helper". Això és perquè la pàgina About ja no existeix i ha estat reemplaçada pel [README de GitHub](https://github.com/noah-nuebling/mac-mouse-fix) per ara.
- Aquesta versió ara inclou arxius dSYM que poden ser utilitzats per qualsevol persona per descodificar informes d'error de Mac Mouse Fix 2.2.4.
- Algunes millores i neteges internes.

---

També comprova la versió anterior [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).