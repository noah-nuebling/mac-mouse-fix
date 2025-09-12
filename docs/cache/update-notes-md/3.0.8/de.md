Mac Mouse Fix **3.0.8** behebt UI-Probleme und mehr.

### **UI-Probleme**

- Ein Fehler wurde behoben, bei dem die 'Kostenlose Tage sind vorbei'-Benachrichtigung in einer Bildschirmecke feststeckte.
    - Tut mir leid wegen diesem Fehler! Ich hoffe, er war nicht zu störend. Und danke an [Sashpuri](https://github.com/Sashpuri) und andere fürs Melden.
- Das neue Design wurde unter macOS 26 Tahoe deaktiviert. Die App wird nun so aussehen und funktionieren wie unter macOS 15 Sequoia.
    - Ich habe das gemacht, weil einige von Apples neu gestalteten UI-Elementen noch nicht richtig funktionieren, was zu Problemen im 'Tasten'-Tab führte. Zum Beispiel waren die '-'-Buttons nicht immer klickbar.
    - Die Benutzeroberfläche mag jetzt unter macOS 26 Tahoe etwas veraltet aussehen. Aber sie sollte wie zuvor voll funktionsfähig und ausgereift sein – das erschien mir für Nutzer wichtiger.

### **UI-Verfeinerungen**

- Die grüne Ampel-Taste im Mac Mouse Fix Hauptfenster wurde deaktiviert.
    - Die Taste war unnötig. Sie hatte keine Funktion, da das Fenster nicht manuell in der Größe verändert werden kann.
- Ein Problem wurde behoben, bei dem einige horizontale Linien in der Tabelle im 'Tasten'-Tab unter macOS 26 Tahoe zu dunkel waren.
- Ein Fehler wurde behoben, bei dem die Nachricht "Primäre Maustaste kann nicht verwendet werden" im 'Tasten'-Tab unter macOS 26 Tahoe manchmal abgeschnitten wurde.
- Ein Tippfehler in der deutschen Oberfläche wurde korrigiert. Dank an GitHub-Nutzer [i-am-the-slime](https://github.com/i-am-the-slime). Danke!
- Ein Problem wurde behoben, bei dem das MMF-Fenster beim Öffnen unter macOS 26 Tahoe manchmal kurz in der falschen Größe aufblitzte.

### **Weitere Änderungen**

- Verbessertes Verhalten beim Versuch, Mac Mouse Fix zu aktivieren, während mehrere Instanzen von Mac Mouse Fix auf dem Computer laufen.
    - Mac Mouse Fix wird nun sorgfältiger versuchen, die andere Instanz von Mac Mouse Fix zu deaktivieren.
    - Dies könnte das Verhalten in einigen Randfällen verbessern, in denen Mac Mouse Fix zuvor nicht aktiviert werden konnte.
- Interne Änderungen und Aufräumarbeiten.

---

Schau dir auch die letzte Version [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7) an.