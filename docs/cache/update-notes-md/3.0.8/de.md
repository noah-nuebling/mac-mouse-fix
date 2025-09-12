Mac Mouse Fix **3.0.8** behebt UI-Probleme und mehr.

### **UI-Probleme**

- Das neue Design unter macOS 26 Tahoe wurde deaktiviert. Die App sieht jetzt aus und funktioniert wie unter macOS 15 Sequoia.
    - Dies wurde gemacht, weil einige von Apples neu gestalteten UI-Elementen noch Probleme haben. Zum Beispiel waren die '-' Buttons im 'Tasten' Tab nicht immer anklickbar.
    - Die Benutzeroberfläche mag unter macOS 26 Tahoe jetzt etwas veraltet aussehen. Aber sie sollte wie zuvor voll funktionsfähig und ausgereift sein.
- Ein Fehler wurde behoben, bei dem die 'Kostenlose Tage sind vorbei' Benachrichtigung in der oberen rechten Bildschirmecke hängen blieb.
    - Danke an [Sashpuri](https://github.com/Sashpuri) und andere für die Meldung!

### **UI-Verbesserungen**

- Die grüne Ampel-Schaltfläche im Mac Mouse Fix Hauptfenster wurde deaktiviert.
    - Die Schaltfläche hatte keine Funktion, da das Fenster nicht manuell in der Größe verändert werden kann.
- Ein Problem wurde behoben, bei dem einige horizontale Linien in der Tabelle im 'Tasten' Tab unter macOS 26 Tahoe zu dunkel waren.
- Ein Fehler wurde behoben, bei dem die Meldung "Primäre Maustaste kann nicht verwendet werden" im 'Tasten' Tab unter macOS 26 Tahoe manchmal abgeschnitten wurde.
- Ein Tippfehler in der deutschen Benutzeroberfläche wurde korrigiert. Mit Dank an GitHub-Nutzer [i-am-the-slime](https://github.com/i-am-the-slime).
- Ein Problem wurde behoben, bei dem das MMF-Fenster beim Öffnen unter macOS 26 Tahoe manchmal kurz in der falschen Größe aufblitzte.

### **Weitere Änderungen**

- Verbessertes Verhalten beim Versuch, Mac Mouse Fix zu aktivieren, während mehrere Instanzen von Mac Mouse Fix auf dem Computer laufen.
    - Mac Mouse Fix wird nun sorgfältiger versuchen, die andere Instanz von Mac Mouse Fix zu deaktivieren.
    - Dies könnte Randfälle verbessern, in denen Mac Mouse Fix nicht aktiviert werden konnte.
- Interne Änderungen und Aufräumarbeiten.

---

Sieh dir auch die Neuerungen der vorherigen Version [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7) an.