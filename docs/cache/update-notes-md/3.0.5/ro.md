Mac Mouse Fix **3.0.5** remediază mai multe erori, îmbunătățește performanța și adaugă un pic de finisare aplicației. \
Este, de asemenea, compatibilă cu macOS 26 Tahoe.

### Simulare îmbunătățită a derulării cu trackpad-ul

- Sistemul de derulare poate acum simula o atingere cu două degete pe trackpad pentru a face aplicațiile să oprească derularea.
    - Aceasta remediază o problemă la rularea aplicațiilor pentru iPhone sau iPad, unde derularea continua adesea după ce utilizatorul alege să oprească.
- Remediată simularea inconsecventă a ridicării degetelor de pe trackpad.
    - Aceasta ar fi putut cauza comportament suboptimal în unele situații.



### Compatibilitate cu macOS 26 Tahoe

Când rulezi versiunea Beta macOS 26 Tahoe, aplicația este acum utilizabilă, iar cea mai mare parte a interfeței funcționează corect.



### Îmbunătățire a performanței

Performanță îmbunătățită pentru gestul Click și Drag pentru "Scroll & Navigate". \
În testele mele, utilizarea CPU-ului a fost redusă cu ~50%!

**Context**

În timpul gestului "Scroll & Navigate", Mac Mouse Fix desenează un cursor fals de mouse într-o fereastră transparentă, în timp ce blochează cursorul real de mouse în poziție. Aceasta asigură că poți continua să derulezi elementul de interfață pe care ai început să-l derulezi, indiferent cât de mult îți miști mouse-ul.

Performanța îmbunătățită a fost obținută prin dezactivarea gestionării implicite a evenimentelor macOS pe această fereastră transparentă, care oricum nu era utilizată.





### Remedieri de erori

- Acum se ignoră evenimentele de derulare de la tabletele grafice Wacom.
    - Înainte, Mac Mouse Fix cauza derulare eratică pe tabletele Wacom, așa cum a raportat @frenchie1980 în GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Mulțumim!)
    
- Remediată o eroare în care codul Swift Concurrency, care a fost introdus ca parte a noului sistem de licențiere în Mac Mouse Fix 3.0.4, nu rula pe thread-ul corect.
    - Aceasta cauza crash-uri pe macOS Tahoe și probabil a cauzat și alte erori sporadice legate de licențiere.
- Îmbunătățită robustețea codului care decodifică licențele offline.
    - Aceasta ocolește o problemă în API-urile Apple care făcea ca validarea licenței offline să eșueze întotdeauna pe Mac Mini-ul meu Intel. Presupun că aceasta se întâmpla pe toate Mac-urile Intel și că a fost motivul pentru care eroarea "Free days are over" (care a fost deja abordată în 3.0.4) încă apărea pentru unii oameni, așa cum a raportat @toni20k5267 în GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Mulțumesc!)
        - Dacă ai experimentat eroarea "Free days are over", îmi pare rău! Poți obține o rambursare [aici](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Îmbunătățiri UX

- Dezactivate dialogurile care ofereau soluții pas cu pas pentru erorile macOS care împiedicau utilizatorii să activeze Mac Mouse Fix.
    - Aceste probleme apăreau doar pe macOS 13 Ventura și 14 Sonoma. Acum, aceste dialoguri apar doar pe acele versiuni de macOS unde sunt relevante. 
    - Dialogurile sunt, de asemenea, puțin mai greu de declanșat – înainte, apăreau uneori în situații în care nu erau foarte utile.
    
- Adăugat un link "Activate License" direct pe notificarea "Free days are over". 
    - Aceasta face activarea unei licențe Mac Mouse Fix și mai simplă!

### Îmbunătățiri vizuale

- Îmbunătățit ușor aspectul ferestrei "Software Update". Acum se potrivește mai bine cu macOS 26 Tahoe. 
    - Aceasta a fost realizată prin personalizarea aspectului implicit al framework-ului "Sparkle 1.27.3" pe care Mac Mouse Fix îl folosește pentru a gestiona actualizările.
- Remediată problema în care textul din partea de jos a tab-ului About era uneori tăiat în chineză, prin lărgirea ușoară a ferestrei.
- Remediat textul din partea de jos a tab-ului About care era ușor decentrat.
- Remediată o eroare care făcea ca spațiul de sub opțiunea "Keyboard Shortcut..." din tab-ul Buttons să fie prea mic. 

### Modificări în fundal

- Eliminată dependența de framework-ul "SnapKit".
    - Aceasta reduce ușor dimensiunea aplicației de la 19.8 la 19.5 MB.
- Diverse alte îmbunătățiri minore în codul sursă.

*Editat cu asistență excelentă de la Claude.*

---

Verifică și versiunea anterioară [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).