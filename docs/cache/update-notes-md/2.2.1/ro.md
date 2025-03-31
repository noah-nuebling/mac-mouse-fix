Mac Mouse Fix **2.2.1** oferă **suport complet pentru macOS Ventura** printre alte modificări.

### Suport pentru Ventura!
Mac Mouse Fix acum suportă complet și se integrează nativ cu macOS 13 Ventura.
Mulțumiri speciale lui [@chamburr](https://github.com/chamburr) care a ajutat cu suportul pentru Ventura în Issue-ul GitHub [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Modificările includ:

- Actualizarea interfeței pentru acordarea Accesului de Accesibilitate pentru a reflecta noile Setări de Sistem din Ventura
- Mac Mouse Fix va fi afișat corect în noul meniu **Setări de Sistem > Elemente de Login** din Ventura
- Mac Mouse Fix va reacționa corespunzător când este dezactivat din **Setări de Sistem > Elemente de Login**

### S-a renunțat la suportul pentru versiuni mai vechi de macOS

Din păcate, Apple permite dezvoltarea _pentru_ macOS 10.13 **High Sierra și versiuni ulterioare** doar când dezvolți _din_ macOS 13 Ventura.

Astfel, **versiunea minimă suportată** a crescut de la 10.11 El Capitan la 10.13 High Sierra.

### Rezolvări de bug-uri

- S-a rezolvat o problemă prin care Mac Mouse Fix modifica comportamentul de derulare pentru unele **tablete grafice**. Vezi Issue-ul GitHub [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- S-a rezolvat o problemă prin care **comenzile rapide** care includeau tasta 'A' nu puteau fi înregistrate. Rezolvă Issue-ul GitHub [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- S-a rezolvat o problemă prin care unele **remapări ale butoanelor** nu funcționau corect când se folosea o configurație de tastatură non-standard.
- S-a rezolvat o eroare în '**Setări specifice aplicațiilor**' când se încerca adăugarea unei aplicații fără 'Bundle ID'. Ar putea ajuta cu Issue-ul GitHub [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- S-a rezolvat o eroare la încercarea de a adăuga aplicații fără nume în '**Setări specifice aplicațiilor**'. Rezolvă Issue-ul GitHub [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Mulțumiri speciale lui [jeongtae](https://github.com/jeongtae) care a fost de mare ajutor în identificarea problemei!
- Mai multe rezolvări minore de bug-uri și îmbunătățiri interne.