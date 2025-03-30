Schau dir auch die **tollen Änderungen** in [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4) an!

---

**3.0.0 Beta 5** stellt die **Kompatibilität** mit einigen **Mäusen** unter macOS 13 Ventura wieder her und **behebt Scrollprobleme** in vielen Apps.
Außerdem enthält es verschiedene kleine Fehlerbehebungen und Verbesserungen der Benutzerfreundlichkeit.

Hier sind **alle Neuigkeiten**:

### Maus

- Scrollen in Terminal und anderen Apps wurde repariert! Siehe GitHub Issue [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Inkompatibilität mit einigen Mäusen unter macOS 13 Ventura wurde behoben, indem unzuverlässige Apple APIs durch Low-Level-Hacks ersetzt wurden. Hoffentlich führt das nicht zu neuen Problemen - lass es mich wissen, falls doch! Besonderen Dank an Maria und GitHub-Nutzer [samiulhsnt](https://github.com/samiulhsnt) für die Hilfe bei der Lösung! Mehr Infos im GitHub Issue [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424).
- Verbraucht keine CPU mehr beim Klicken der Maustasten 1 oder 2. Leicht reduzierter CPU-Verbrauch beim Klicken anderer Tasten.
    - Dies ist ein "Debug Build", daher kann die CPU-Auslastung beim Klicken von Tasten in dieser Beta etwa 10-mal höher sein als in der finalen Version
- Die Trackpad-Scroll-Simulation, die für Mac Mouse Fix' "Smooth Scrolling" und "Scroll & Navigate" Funktionen verwendet wird, ist jetzt noch präziser. Dies könnte in manchen Situationen zu besserem Verhalten führen.

### Benutzeroberfläche

- Automatische Behebung von Problemen mit der Zugriffserlaubnis für Bedienungshilfen nach dem Update von einer älteren Version von Mac Mouse Fix. Übernimmt die Änderungen aus den [2.2.2 Release Notes](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- "Abbrechen"-Button zum "Zugriffserlaubnis für Bedienungshilfen"-Bildschirm hinzugefügt
- Ein Problem wurde behoben, bei dem die Konfiguration von Mac Mouse Fix nach der Installation einer neuen Version nicht richtig funktionierte, weil die neue Version sich mit der alten Version von "Mac Mouse Fix Helper" verband. Jetzt verbindet sich Mac Mouse Fix nicht mehr mit dem alten "Mac Mouse Fix Helper" und deaktiviert die alte Version automatisch wenn nötig.
- Benutzeranweisungen zur Behebung eines Problems hinzugefügt, bei dem Mac Mouse Fix aufgrund einer anderen Version im System nicht richtig aktiviert werden kann. Dieses Problem tritt nur unter macOS Ventura auf.
- Verbessertes Verhalten und Animationen im "Zugriffserlaubnis für Bedienungshilfen"-Bildschirm
- Mac Mouse Fix wird in den Vordergrund gebracht, wenn es aktiviert wird. Dies verbessert die UI-Interaktionen in bestimmten Situationen, wie zum Beispiel wenn du Mac Mouse Fix aktivierst, nachdem es unter Systemeinstellungen > Allgemein > Anmeldeobjekte deaktiviert wurde.
- Verbesserte UI-Texte im "Zugriffserlaubnis für Bedienungshilfen"-Bildschirm
- Verbesserte UI-Texte, die angezeigt werden, wenn versucht wird, Mac Mouse Fix zu aktivieren, während es in den Systemeinstellungen deaktiviert ist
- Einen deutschen UI-Text korrigiert

### Unter der Haube

- Die Build-Nummer von "Mac Mouse Fix" und dem eingebetteten "Mac Mouse Fix Helper" sind jetzt synchronisiert. Dies verhindert, dass sich "Mac Mouse Fix" versehentlich mit alten Versionen von "Mac Mouse Fix Helper" verbindet.
- Problem behoben, bei dem einige Daten zu deiner Lizenz und Testperiode beim ersten Start der App manchmal falsch angezeigt wurden, indem Cache-Daten aus der Erstkonfiguration entfernt wurden
- Viele Aufräumarbeiten an der Projektstruktur und dem Quellcode
- Verbesserte Debug-Meldungen

---

### Wie du helfen kannst

Du kannst helfen, indem du deine **Ideen**, **Probleme** und **Rückmeldungen** teilst!

Der beste Ort für deine **Ideen** und **Probleme** ist der [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Der beste Ort für **schnelle**, unstrukturierte Rückmeldungen ist die [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Du kannst diese Orte auch direkt aus der App im "**ⓘ Über**"-Tab erreichen.

**Danke**, dass du hilfst, Mac Mouse Fix besser zu machen! 💙💛❤️