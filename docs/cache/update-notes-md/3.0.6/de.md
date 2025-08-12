**ℹ️ Hinweis für Mac Mouse Fix 2 Nutzer**

Mit der Einführung von Mac Mouse Fix 3 hat sich das Preismodell der App geändert:

- **Mac Mouse Fix 2**\
Bleibt zu 100% kostenlos und ich plane, es weiterhin zu unterstützen.\
**Überspringe dieses Update**, um Mac Mouse Fix 2 weiter zu nutzen. Lade die neueste Version von Mac Mouse Fix 2 [hier](https://redirect.macmousefix.com/?target=mmf2-latest) herunter.
- **Mac Mouse Fix 3**\
30 Tage kostenlos, kostet dann ein paar Dollar zum Kauf.\
**Jetzt updaten**, um Mac Mouse Fix 3 zu erhalten!

Mehr über die Preise und Funktionen von Mac Mouse Fix 3 erfährst du auf der [neuen Website](https://macmousefix.com/).

Danke, dass du Mac Mouse Fix nutzt! :)

---

**ℹ️ Hinweis für Mac Mouse Fix 3 Käufer**

Falls du versehentlich auf Mac Mouse Fix 3 aktualisiert hast, ohne zu wissen, dass es nicht mehr kostenlos ist, möchte ich dir eine [Rückerstattung](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) anbieten.

Die neueste Version von Mac Mouse Fix 2 bleibt **komplett kostenlos** und du kannst sie [hier](https://redirect.macmousefix.com/?target=mmf2-latest) herunterladen.

Tut mir leid für die Umstände, und ich hoffe, diese Lösung ist für alle in Ordnung!

---

Mac Mouse Fix **3.0.6** macht die 'Zurück' und 'Vorwärts' Funktion mit mehr Apps kompatibel.
Außerdem wurden verschiedene Bugs und Probleme behoben.

### Verbesserte 'Zurück' und 'Vorwärts' Funktion

Die Maustasten-Zuweisungen für 'Zurück' und 'Vorwärts' **funktionieren jetzt in mehr Apps**, darunter:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed und andere Code-Editoren
- Viele eingebaute Apple Apps wie Preview, Notizen, Systemeinstellungen, App Store und Musik
- Adobe Acrobat
- Zotero
- Und mehr!

Die Implementierung ist inspiriert von der großartigen 'Universal Back and Forward' Funktion in [LinearMouse](https://github.com/linearmouse/linearmouse). Sie sollte alle Apps unterstützen, die auch LinearMouse unterstützt. \
Darüber hinaus werden einige Apps unterstützt, die normalerweise Tastaturkürzel für Vor- und Zurück-Navigation benötigen, wie Systemeinstellungen, App Store, Apple Notizen und Adobe Acrobat. Mac Mouse Fix erkennt diese Apps jetzt und simuliert die entsprechenden Tastaturkürzel.

Jede App, die jemals in einem [GitHub Issue angefragt](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) wurde, sollte jetzt unterstützt werden! (Danke für das Feedback!) \
Falls du Apps findest, die noch nicht funktionieren, lass es mich in einer [Feature-Anfrage](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request) wissen.

### Behebung des 'Scrollen funktioniert zeitweise nicht' Bugs

Einige Nutzer erlebten ein [Problem](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22), bei dem **sanftes Scrollen zufällig aufhörte** zu funktionieren.

Obwohl ich das Problem nie selbst reproduzieren konnte, habe ich eine mögliche Lösung implementiert:

Die App wird jetzt mehrmals versuchen, die Display-Synchronisation einzurichten, wenn es beim ersten Mal fehlschlägt. \
Wenn es nach mehreren Versuchen immer noch nicht funktioniert, wird die App:

- Den 'Mac Mouse Fix Helper' Hintergrundprozess neustarten, was das Problem möglicherweise löst
- Einen Absturzbericht erstellen, der bei der Diagnose des Bugs helfen könnte

Ich hoffe, das Problem ist jetzt gelöst! Falls nicht, lass es mich in einem [Fehlerbericht](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) oder per [E-Mail](http://redirect.macmousefix.com/?target=mailto-noah) wissen.

### Verbessertes Verhalten bei Freilauf-Scrollrädern

Mac Mouse Fix wird **das Scrollen nicht mehr beschleunigen**, wenn du das Scrollrad der MX Master Maus (oder einer anderen Maus mit Freilauf-Scrollrad) frei drehen lässt.

Während diese 'Scroll-Beschleunigung' bei normalen Scrollrädern nützlich ist, kann sie bei einem Freilauf-Scrollrad die Kontrolle erschweren.

**Hinweis:** Mac Mouse Fix ist derzeit nicht vollständig kompatibel mit den meisten Logitech-Mäusen, einschließlich der MX Master. Ich plane, volle Unterstützung hinzuzufügen, aber das wird wahrscheinlich noch eine Weile dauern. In der Zwischenzeit ist der beste Drittanbieter-Treiber mit Logitech-Unterstützung, den ich kenne, [SteerMouse](https://plentycom.jp/en/steermouse/).

### Fehlerbehebungen

- Ein Problem wurde behoben, bei dem Mac Mouse Fix manchmal Tastaturkürzel wieder aktivierte, die zuvor in den Systemeinstellungen deaktiviert wurden
- Ein Absturz beim Klicken auf 'Lizenz aktivieren' wurde behoben
- Ein Absturz beim Klicken auf 'Abbrechen' direkt nach dem Klick auf 'Lizenz aktivieren' wurde behoben (Danke für den Hinweis, Ali!)
- Abstürze wurden behoben, die auftraten, wenn Mac Mouse Fix ohne angeschlossenen Bildschirm verwendet wurde
- Ein Speicherleck und einige andere interne Probleme beim Wechseln zwischen Tabs in der App wurden behoben

### Visuelle Verbesserungen

- Ein Problem wurde behoben, bei dem der About-Tab manchmal zu hoch war, das in [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5) eingeführt wurde
- Text in der 'Kostenlose Tage sind vorbei' Benachrichtigung wird in Chinesisch nicht mehr abgeschnitten
- Ein visueller Fehler beim Schatten des '+' Feldes nach der Aufnahme einer Eingabe wurde behoben
- Ein seltener Fehler wurde behoben, bei dem der Platzhaltertext im 'Lizenzschlüssel eingeben' Bildschirm nicht zentriert erschien
- Ein Problem wurde behoben, bei dem einige in der App angezeigte Symbole nach dem Wechsel zwischen Hell-/Dunkel-Modus die falsche Farbe hatten

### Weitere Verbesserungen

- Einige Animationen, wie die Tab-Wechsel-Animation, wurden etwas effizienter gestaltet
- Touch Bar Textvervollständigung wurde im 'Lizenzschlüssel eingeben' Bildschirm deaktiviert
- Verschiedene kleinere interne Verbesserungen

*Bearbeitet mit hervorragender Unterstützung von Claude.*

---

Sieh dir auch das vorherige Release [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5) an