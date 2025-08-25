Mac Mouse Fix **3.0.6** macht die 'Zurück'- und 'Vorwärts'-Funktion mit mehr Apps kompatibel.
Außerdem wurden verschiedene Bugs und Probleme behoben.

### Verbesserte 'Zurück'- und 'Vorwärts'-Funktion

Die Maustasten-Zuweisungen für 'Zurück' und 'Vorwärts' **funktionieren jetzt in mehr Apps**, darunter:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed und andere Code-Editoren
- Viele integrierte Apple-Apps wie Vorschau, Notizen, Systemeinstellungen, App Store und Musik
- Adobe Acrobat
- Zotero
- Und weitere!

Die Implementierung wurde von der großartigen 'Universal Back and Forward'-Funktion in [LinearMouse](https://github.com/linearmouse/linearmouse) inspiriert. Sie sollte alle Apps unterstützen, die auch LinearMouse unterstützt. \
Darüber hinaus werden einige Apps unterstützt, die normalerweise Tastaturkürzel für Vor- und Zurück benötigen, wie Systemeinstellungen, App Store, Apple Notizen und Adobe Acrobat. Mac Mouse Fix erkennt diese Apps jetzt und simuliert die entsprechenden Tastaturkürzel.

Jede App, die jemals in einem [GitHub Issue angefragt wurde](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22), sollte jetzt unterstützt werden! (Danke für das Feedback!) \
Falls du Apps findest, die noch nicht funktionieren, lass es mich in einer [Funktionsanfrage](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request) wissen.

### Behebung des 'Scrollen funktioniert zeitweise nicht'-Bugs

Einige Nutzer erlebten ein [Problem](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22), bei dem **sanftes Scrollen** zufällig nicht mehr funktionierte.

Obwohl ich das Problem nie selbst reproduzieren konnte, habe ich eine mögliche Lösung implementiert:

Die App wird jetzt mehrmals versuchen, die Display-Synchronisation einzurichten, wenn diese fehlschlägt. \
Wenn es nach mehreren Versuchen immer noch nicht funktioniert, wird die App:

- Den 'Mac Mouse Fix Helper' Hintergrundprozess neu starten, was das Problem möglicherweise löst
- Einen Absturzbericht erstellen, der bei der Diagnose des Bugs helfen könnte

Ich hoffe, das Problem ist jetzt gelöst! Falls nicht, lass es mich in einem [Fehlerbericht](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) oder per [E-Mail](http://redirect.macmousefix.com/?target=mailto-noah) wissen.

### Verbessertes Verhalten bei frei drehenden Scrollrädern

Mac Mouse Fix wird **das Scrollen nicht mehr beschleunigen**, wenn du das Scrollrad der MX Master Maus frei drehen lässt. (Oder bei jeder anderen Maus mit frei drehendem Scrollrad.)

Während diese 'Scroll-Beschleunigung' bei normalen Scrollrädern nützlich ist, kann sie bei einem frei drehenden Scrollrad die Kontrolle erschweren.

**Hinweis:** Mac Mouse Fix ist derzeit nicht vollständig kompatibel mit den meisten Logitech-Mäusen, einschließlich der MX Master. Ich plane volle Unterstützung hinzuzufügen, aber das wird wahrscheinlich noch eine Weile dauern. In der Zwischenzeit ist der beste Drittanbieter-Treiber mit Logitech-Unterstützung, den ich kenne, [SteerMouse](https://plentycom.jp/en/steermouse/).

### Fehlerbehebungen

- Ein Problem wurde behoben, bei dem Mac Mouse Fix manchmal Tastaturkürzel wieder aktivierte, die zuvor in den Systemeinstellungen deaktiviert wurden
- Ein Absturz beim Klicken auf 'Lizenz aktivieren' wurde behoben
- Ein Absturz beim Klicken auf 'Abbrechen' direkt nach dem Klick auf 'Lizenz aktivieren' wurde behoben (Danke für den Hinweis, Ali!)
- Abstürze wurden behoben, die auftraten, wenn Mac Mouse Fix ohne angeschlossenen Bildschirm verwendet wurde
- Ein Speicherleck und einige andere interne Probleme beim Wechseln zwischen Tabs in der App wurden behoben

### Visuelle Verbesserungen

- Ein Problem wurde behoben, bei dem der About-Tab manchmal zu hoch war, das in [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5) eingeführt wurde
- Text auf der 'Kostenlose Tage sind vorbei'-Benachrichtigung wird in Chinesisch nicht mehr abgeschnitten
- Ein visueller Fehler beim Schatten des '+'-Feldes nach der Aufnahme einer Eingabe wurde behoben
- Ein seltener Fehler wurde behoben, bei dem der Platzhaltertext auf dem 'Lizenzschlüssel eingeben'-Bildschirm nicht zentriert erschien
- Ein Problem wurde behoben, bei dem einige in der App angezeigte Symbole nach dem Wechsel zwischen Hell-/Dunkelmodus die falsche Farbe hatten

### Weitere Verbesserungen

- Einige Animationen, wie die Tab-Wechsel-Animation, wurden etwas effizienter gestaltet
- Touch Bar Textvervollständigung wurde auf dem 'Lizenzschlüssel eingeben'-Bildschirm deaktiviert
- Verschiedene kleinere interne Verbesserungen

*Bearbeitet mit hervorragender Unterstützung von Claude.*

---

Sieh dir auch das vorherige Release [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5) an.