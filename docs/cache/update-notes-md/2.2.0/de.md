Schau dir auch die **coolen Features** an, die in [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0) eingeführt wurden!

---

Mac Mouse Fix **2.2.0** bringt verschiedene Verbesserungen der Benutzerfreundlichkeit und Fehlerbehebungen!

### Zuordnung zu Apple-exklusiven Funktionstasten ist jetzt besser

Das letzte Update, 2.1.0, führte ein cooles neues Feature ein, mit dem du deine Maustasten jeder Taste auf deiner Tastatur zuordnen kannst - sogar Funktionstasten, die es nur auf Apple-Tastaturen gibt. 2.2.0 bringt weitere Verbesserungen und Verfeinerungen dieses Features:

- Du kannst jetzt die Option-Taste (⌥) halten, um Tasten zuzuordnen, die es nur auf Apple-Tastaturen gibt - auch wenn du keine Apple-Tastatur zur Hand hast.
- Die Funktionstasten-Symbole haben ein verbessertes Aussehen und passen besser zum restlichen Text.
- Die Möglichkeit, der Feststelltaste zuzuordnen, wurde deaktiviert. Sie funktionierte nicht wie erwartet.

### Aktionen einfacher hinzufügen / entfernen

Einige Nutzer hatten Schwierigkeiten zu erkennen, dass man Aktionen zur Aktionstabelle hinzufügen und daraus entfernen kann. Um dies verständlicher zu machen, bringt 2.2.0 folgende Änderungen und neue Features:

- Du kannst Aktionen jetzt per Rechtsklick löschen.
  - Dies macht die Option zum Löschen von Aktionen leichter zu entdecken.
  - Das Rechtsklick-Menü zeigt ein Symbol des '-'-Buttons. Dies soll die Aufmerksamkeit auf den '-'-_Button_ lenken, was dann auch auf den '+'-Button aufmerksam machen soll. Dadurch wird hoffentlich auch die Option zum **Hinzufügen** von Aktionen leichter erkennbar.
- Du kannst jetzt Aktionen zur Aktionstabelle hinzufügen, indem du eine leere Zeile rechtsklickst.
- Der '-'-Button ist jetzt nur aktiv, wenn eine Aktion ausgewählt ist. Dies verdeutlicht, dass der '-'-Button die ausgewählte Aktion löscht.
- Die Standard-Fensterhöhe wurde vergrößert, sodass eine sichtbare leere Zeile vorhanden ist, die zum Hinzufügen einer Aktion rechtsklickbar ist.
- Die '+' und '-' Buttons haben jetzt Tooltips.

### Klicken und Ziehen Verbesserungen

Der Schwellenwert für die Aktivierung von Klicken und Ziehen wurde von 5 auf 7 Pixel erhöht. Dies macht es schwieriger, Klicken und Ziehen versehentlich zu aktivieren, während Nutzer weiterhin Spaces etc. mit kleinen, komfortablen Bewegungen wechseln können.

### Andere UI-Änderungen

- Das Erscheinungsbild der Aktionstabelle wurde verbessert.
- Verschiedene andere UI-Verbesserungen.

### Fehlerbehebungen

- Ein Problem wurde behoben, bei dem die UI nicht ausgegraut wurde, wenn MMF im deaktivierten Zustand gestartet wurde.
- Die versteckte "Button 3 Klicken und Ziehen" Option wurde entfernt.
  - Bei Auswahl dieser Option stürzte die App ab. Ich hatte diese Option entwickelt, um Mac Mouse Fix besser mit Blender kompatibel zu machen. In ihrer jetzigen Form ist sie jedoch nicht sehr nützlich für Blender-Nutzer, da sie nicht mit Tastaturmodifikatoren kombiniert werden kann. Ich plane, die Blender-Kompatibilität in einem zukünftigen Release zu verbessern.