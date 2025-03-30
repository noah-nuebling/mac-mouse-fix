Mac Mouse Fix **3.0.2** bringt mehrere Verbesserungen, darunter **geschmeidigeres Scrollen**, verbesserte Übersetzungen und mehr!

### Scrollen

- Du kannst Scroll-Animationen jetzt stoppen, indem du einen Schritt in die entgegengesetzte Richtung scrollst. Dies ermöglicht es dir, die Seite bei Verwendung von 'Geschmeidigkeit: Hoch' ähnlich wie bei einem Trackpad zu **'werfen'** und zu **'fangen'**.
- Mac Mouse Fix sendet Scroll-Events nun früher im Bildschirm-Aktualisierungszyklus, wodurch Apps mehr Zeit haben, die Scroll-Events zu verarbeiten und das Scrollen flüssig darzustellen. Dies **verbessert die Bildrate**, besonders auf komplexen Websites wie YouTube.com.
- Verbesserte Reaktionsfähigkeit der 'Geschmeidigkeit: Hoch' Einstellung, wodurch das Scrollen leichter zu kontrollieren ist.
- Verbesserung eines in 3.0.1 eingeführten Mechanismus, bei dem die Animationsgeschwindigkeit bei 'Geschmeidigkeit: Normal' schneller wird, je schneller du das Scrollrad bewegst. In 3.0.2 erscheint die Beschleunigung der Animation konsistenter und vorhersehbarer, was sie angenehmer für die Augen macht und gleichzeitig eine gute Kontrolle ermöglicht.
- Ein Problem wurde behoben, bei dem die Scrollgeschwindigkeit zu langsam war, besonders bei Verwendung der 'Präzision' Option. Dieses Problem wurde in 3.0.1 eingeführt. Danke an @V-Coba, der in [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795) darauf aufmerksam gemacht hat.
- Verbessertes Verhalten im Arc Browser bei Verwendung von 'Klicken und Scrollen' zum 'Rein- oder Rauszoomen'.

### Lokalisierung

- Aktualisierte 🇻🇳 Vietnamesische Übersetzungen. Dank an @nghlt!
- Verbesserte einige 🇩🇪 Deutsche Übersetzungen.
- Text in Mac Mouse Fix, der keine Übersetzung für die aktuelle Sprache hat, zeigt jetzt einen Platzhalter an, anstatt einfach leer zu bleiben. Dies sollte die Navigation in der App bei fehlenden Übersetzungen weniger verwirrend machen.

### Sonstiges

- Mac Mouse Fix zeigt jetzt eine Benachrichtigung mit einem Link zu [diesem Leitfaden](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) für Benutzer, die möglicherweise von einem Bug in macOS 13 Ventura und höher betroffen sind, der verhindern kann, dass Mac Mouse Fix aktiviert wird.
- Geänderte Standardeinstellungen für Mäuse mit 3 Tasten. Die Standardeinstellungen beinhalten nicht mehr eine 'Klicken und Scrollen' Aktion für die Scrollrad-Taste, da diese ziemlich schwer auszuführen ist. Stattdessen gibt es nun eine 'Halten' und eine 'Doppelklick' Aktion.
- Dem Mac Mouse Fix Symbol im Über-Tab wurde ein Tooltip hinzugefügt. Er erklärt dir, wie du Mac Mouse Fix's Konfigurationsdatei im Finder anzeigen kannst.
- Viele Verbesserungen und Aufräumarbeiten unter der Haube.

---

Sieh dir auch das vorherige Release [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1) an.