Schau dir auch die **tollen Änderungen** in [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5) an!


---

**3.0.0 Beta 6** bringt tiefgreifende Optimierungen und Verfeinerungen, eine Überarbeitung der Scroll-Einstellungen, chinesische Übersetzungen und mehr!

Hier sind alle Neuigkeiten:

## 1. Tiefgreifende Optimierungen

Für diese Beta habe ich viel Arbeit investiert, um die letzte Performance aus Mac Mouse Fix herauszuholen. Und jetzt kann ich mit Freude verkünden, dass Mausklicks in Beta 6 im Vergleich zur vorherigen Beta **2x** schneller sind! Und das Scrollen ist sogar **4x** schneller!

Mit Beta 6 wird MMF auch intelligent Teile von sich selbst abschalten, um CPU und Akku bestmöglich zu schonen.

Zum Beispiel, wenn du gerade eine Maus mit 3 Tasten verwendest, aber nur Aktionen für Tasten eingerichtet hast, die nicht auf deiner Maus vorhanden sind (wie Tasten 4 und 5), wird Mac Mouse Fix komplett aufhören, auf Tasteneingaben deiner Maus zu achten. Das bedeutet 0% CPU-Nutzung beim Klicken! Oder wenn die Scroll-Einstellungen in MMF mit den Systemeinstellungen übereinstimmen, wird Mac Mouse Fix komplett aufhören, auf Eingaben vom Scrollrad zu achten. Das bedeutet 0% CPU-Nutzung beim Scrollen! Aber wenn du die Befehlstaste (⌘)-Scroll zum Zoomen-Funktion einrichtest, wird Mac Mouse Fix anfangen, auf dein Scrollrad zu achten - aber nur während du die Befehlstaste (⌘) gedrückt hältst. Und so weiter.
Es ist also wirklich intelligent und verbraucht nur dann CPU, wenn es nötig ist!

Das bedeutet, MMF ist jetzt nicht nur der mächtigste, benutzerfreundlichste und ausgefeilteste Maustreiber für Mac, sondern auch einer der, wenn nicht sogar der optimierteste und effizienteste!

## 2. Reduzierte App-Größe

Mit 16 MB ist Beta 6 ca. 2x kleiner als Beta 5!

Dies ist ein Nebeneffekt der eingestellten Unterstützung für ältere macOS-Versionen.

## 3. Eingestellte Unterstützung für ältere macOS-Versionen

Ich habe hart daran gearbeitet, MMF 3 auf macOS-Versionen vor macOS 11 Big Sur zum Laufen zu bringen. Aber der Aufwand, um es ausgereift zu gestalten, erwies sich als überwältigend, sodass ich das aufgeben musste.

In Zukunft wird die früheste offiziell unterstützte Version macOS 11 Big Sur sein.

Die App wird sich auf älteren Versionen noch öffnen, aber es wird visuelle und möglicherweise andere Probleme geben. Die App wird sich auf macOS-Versionen vor 10.14.4 nicht mehr öffnen. Dies ermöglicht uns die 2-fache Verkleinerung der App-Größe, da 10.14.4 die früheste macOS-Version ist, die mit modernen Swift-Bibliotheken ausgeliefert wird (siehe "Swift ABI Stability"), was bedeutet, dass diese Swift-Bibliotheken nicht mehr in der App enthalten sein müssen.

## 4. Scroll-Verbesserungen

Beta 6 enthält viele Verbesserungen an der Konfiguration und der Benutzeroberfläche der neuen Scrollsysteme, die in MMF 3 eingeführt wurden.

### Benutzeroberfläche

- Stark vereinfachter und gekürzter UI-Text im Scroll-Tab. Die meisten Erwähnungen des Wortes "Scroll" wurden entfernt, da sie sich aus dem Kontext ergeben.
- Überarbeitete Scroll-Geschmeidigkeitseinstellungen für mehr Klarheit und zusätzliche Optionen. Jetzt kannst du zwischen einer "Geschmeidigkeit" von "Aus", "Normal" oder "Hoch" wählen, was den alten "mit Trägheit"-Schalter ersetzt. Ich denke, das ist viel klarer und es schaffte Platz in der UI für die neue "Trackpad-Simulation"-Option.
- Das Ausschalten der neuen "Trackpad-Simulation"-Option deaktiviert den Gummiband-Effekt beim Scrollen, verhindert auch das Scrollen zwischen Seiten in Safari und anderen Apps, und mehr. Viele Leute waren davon genervt, besonders diejenigen mit freilaufenden Scrollrädern wie bei einigen Logitech-Mäusen wie der MX Master, aber andere mögen es, also habe ich beschlossen, es zu einer Option zu machen. Ich hoffe, die Präsentation der Funktion ist klar. Wenn du Vorschläge hast, lass es mich wissen.
- Die Option "Natürliche Scrollrichtung" wurde zu "Scrollrichtung umkehren" geändert. Das bedeutet, die Einstellung kehrt jetzt die System-Scrollrichtung um und ist nicht mehr unabhängig von der System-Scrollrichtung. Während dies möglicherweise eine etwas schlechtere Benutzererfahrung ist, ermöglicht diese neue Art einige Optimierungen und macht es für den Benutzer transparenter, wie man Mac Mouse Fix fürs Scrollen komplett ausschaltet.
- Verbesserte Interaktion der Scroll-Einstellungen mit modifiziertem Scrollen in vielen verschiedenen Randfällen. Z.B. wird die "Präzision"-Option nicht mehr auf die "Klicken und Scrollen" für "Desktop & Launchpad"-Aktion angewendet, da sie hier eher hinderlich als hilfreich ist.
- Verbesserte Scrollgeschwindigkeit bei Verwendung von "Klicken und Scrollen" für "Desktop & Launchpad" oder "Rein- oder Rauszoomen" und anderen Funktionen.
- Entfernung des nicht funktionierenden Links zu den System-Scrollgeschwindigkeitseinstellungen im Scroll-Tab, der in macOS-Versionen vor macOS 13.0 Ventura vorhanden war. Ich konnte keinen Weg finden, den Link zum Funktionieren zu bringen, und es ist nicht besonders wichtig.

### Scroll-Gefühl

- Verbesserte Animationskurve für "Normale Geschmeidigkeit" (früher zugänglich durch Ausschalten von "mit Trägheit"). Dies macht alles geschmeidiger und reaktionsschneller.
- Verbessertes Gefühl aller Scroll-Geschwindigkeitseinstellungen. Die "Mittlere" und "Schnelle" Geschwindigkeit sind schneller. Es gibt mehr Unterschied zwischen "Niedrig", "Mittel" und "Hoch". Die Beschleunigung beim schnelleren Bewegen des Scrollrads fühlt sich natürlicher und angenehmer an bei Verwendung der "Präzision"-Option.
- Die Art, wie die Scrollgeschwindigkeit zunimmt, wenn du in eine Richtung weiterschrollst, fühlt sich natürlicher und gradueller an. Ich verwende neue mathematische Kurven, um die Beschleunigung zu modellieren. Die Geschwindigkeitszunahme wird auch schwieriger versehentlich auszulösen sein.
- Keine Erhöhung der Scrollgeschwindigkeit mehr beim kontinuierlichen Scrollen in eine Richtung bei Verwendung der "macOS"-Scrollgeschwindigkeit.
- Beschränkung der Scroll-Animationszeit auf ein Maximum. Wenn die Scroll-Animation natürlicherweise länger dauern würde, wird sie beschleunigt, um unter der maximalen Zeit zu bleiben. Dadurch wird beim Scrollen an den Seitenrand mit einem freilaufenden Rad der Seiteninhalt nicht so lange außerhalb des Bildschirms bewegt. Dies sollte normales Scrollen mit einem nicht-freilaufenden Rad nicht beeinflussen.
- Verbesserte Interaktionen rund um den Gummiband-Effekt beim Scrollen an den Seitenrand in Safari und anderen Apps.
- Behebung eines Problems, bei dem "Klicken und Scrollen" und andere scroll-bezogene Funktionen nach einem Upgrade von einer sehr alten Einstellungsfeld-Version von Mac Mouse Fix nicht richtig funktionierten.
- Behebung eines Problems, bei dem Einzel-Pixel-Scrolls mit Verzögerung gesendet wurden bei Verwendung der "macOS"-Scrollgeschwindigkeit zusammen mit geschmeidigem Scrollen.
- Behebung eines Fehlers, bei dem das Scrollen nach dem Loslassen des Schnell-Scroll-Modifikators immer noch sehr schnell war. Weitere Verbesserungen daran, wie die Scrollgeschwindigkeit von vorherigen Scroll-Wischgesten übernommen wird.
- Verbesserte Art, wie die Scrollgeschwindigkeit mit größeren Display-Größen zunimmt.

## 5. Notarisierung

Ab 3.0.0 Beta 6 wird Mac Mouse Fix "Notarisiert" sein. Das bedeutet keine weiteren Meldungen mehr über Mac Mouse Fix als potenziell "Schädliche Software" beim ersten Öffnen der App.

Die Notarisierung einer App kostet $100 pro Jahr. Ich war immer dagegen, da es sich feindlich gegenüber freier und Open-Source-Software wie Mac Mouse Fix anfühlte, und es sich auch wie ein gefährlicher Schritt in Richtung Apple's Kontrolle und Abschottung des Mac wie bei iOS anfühlte. Aber der Mangel an Notarisierung führte zu ziemlich schwerwiegenden Problemen, einschließlich [mehrerer Situationen](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114), in denen niemand die App nutzen konnte, bis ich eine neue Version veröffentlichte. Da Mac Mouse Fix jetzt monetarisiert wird, dachte ich, es wäre endlich angemessen, die App für eine einfachere und stabilere Benutzererfahrung zu notarisieren.

## 6. Chinesische Übersetzungen

Mac Mouse Fix ist jetzt auf Chinesisch verfügbar!
Genauer gesagt ist es verfügbar in:

- Chinesisch, Traditionell
- Chinesisch, Vereinfacht
- Chinesisch (Hong Kong)

Großen Dank an @groverlynn für die Bereitstellung all dieser Übersetzungen sowie für deren Aktualisierung während der Betas und die Kommunikation mit mir. Siehe seinen Pull Request hier: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Alles Weitere

Neben den oben aufgeführten Änderungen enthält Beta 6 auch viele kleinere Verbesserungen.

- Entfernung mehrerer Optionen aus den "Klicken", "Klicken und Halten" und "Klicken und Scrollen" Aktionen, da ich sie für redundant hielt, da die gleiche Funktionalität anders erreicht werden kann und dies die Menüs stark vereinfacht. Werde diese Optionen zurückbringen, wenn sich Leute beschweren. Also wenn du diese Optionen vermisst - bitte beschwere dich.
- Klicken-und-Ziehen-Richtung wird jetzt der Trackpad-Wischrichtung entsprechen, auch wenn "Natürliches Scrollen" unter Systemeinstellungen > Trackpad ausgeschaltet ist. Vorher verhielt sich Klicken und Ziehen immer wie Wischen auf dem Trackpad mit eingeschaltetem "Natürlichen Scrollen".
- Behebung eines Problems, bei dem die Cursor verschwanden und dann woanders wieder auftauchten bei Verwendung einer "Klicken und Ziehen"-Aktion während einer Bildschirmaufnahme oder bei Verwendung der DisplayLink-Software.
- Behebung der Zentrierung des "+" im "+"-Feld auf dem Tasten-Tab
- Mehrere visuelle Verbesserungen am Tasten-Tab. Die Farbpalette des "+"-Feldes und der Aktions-Tabelle wurde überarbeitet, um korrekt auszusehen bei Verwendung von macOS' "Hintergrundbild-Tönung in Fenstern zulassen"-Option. Die Ränder der Aktions-Tabelle haben jetzt eine transparente Farbe, die dynamischer aussieht und sich ihrer Umgebung anpasst.
- Wenn du viele Aktionen zur Aktions-Tabelle hinzufügst und das Mac Mouse Fix Fenster wächst, wird es genau so groß wie der Bildschirm (oder wie der Bildschirm minus Dock, wenn du Dock-Ausblenden nicht aktiviert hast) und dann stoppen. Wenn du noch mehr Aktionen hinzufügst, wird die Aktions-Tabelle anfangen zu scrollen.
- Diese Beta unterstützt jetzt einen neuen Checkout, wo du eine Lizenz in US-Dollar kaufen kannst wie beworben. Vorher konnte man nur eine Lizenz in Euro kaufen. Die alten Euro-Lizenzen werden natürlich weiterhin unterstützt.
- Behebung eines Problems, bei dem Momentum-Scrollen manchmal nicht gestartet wurde bei Verwendung der "Scrollen & Navigieren"-Funktion.
- Wenn sich das Mac Mouse Fix Fenster während eines Tab-Wechsels selbst vergrößert, wird es sich jetzt neu positionieren, sodass es sich nicht mit dem Dock überschneidet
- Behebung von Flackern bei einigen UI-Elementen beim Wechsel vom Tasten-Tab zu einem anderen Tab
- Verbesserte Erscheinung der Animation, die das "+"-Feld nach der Aufnahme einer Eingabe abspielt. Besonders auf macOS-Versionen vor Ventura, wo der Schatten des "+"-Feldes während der Animation fehlerhaft erschien.
- Deaktivierung von Benachrichtigungen, die mehrere Tasten auflisten, die von Mac Mouse Fix erfasst wurden/nicht mehr erfasst werden, die beim ersten Start der App oder beim Laden einer Voreinstellung erschienen. Ich fand diese Nachrichten ablenkend und leicht überwältigend und in diesen Kontexten nicht wirklich hilfreich.
- Überarbeitung des Zugriffsrechte-Gewährungs-Bildschirms. Er wird jetzt Informationen darüber, warum Mac Mouse Fix Zugriffsrechte benötigt, direkt anzeigen, anstatt auf die Website zu verlinken, und ist etwas klarer und hat ein optisch ansprechenderes Layout.
- Aktualisierung des Danksagungen-Links im Über-Tab.
- Verbesserte Fehlermeldungen, wenn Mac Mouse Fix nicht aktiviert werden kann, weil eine andere Version im System vorhanden ist. Die Meldung wird jetzt in einem schwebenden Warnfenster angezeigt, das immer über anderen Fenstern bleibt, bis es geschlossen wird, anstatt einer Toast-Benachrichtigung, die verschwindet, wenn irgendwo geklickt wird. Dies sollte es einfacher machen, den vorgeschlagenen Lösungsschritten zu folgen.
- Behebung einiger Probleme mit der Markdown-Darstellung auf macOS-Versionen vor Ventura. MMF wird jetzt eine eigene Markdown-Rendering-Lösung für alle macOS-Versionen verwenden, einschließlich Ventura. Vorher verwendeten wir eine in Ventura eingeführte System-API, aber das führte zu Inkonsistenzen. Markdown wird verwendet, um Links und Hervorhebungen zu Text in der gesamten UI hinzuzufügen.
- Verfeinerung der Interaktionen rund um die Aktivierung der Zugriffsrechte.
- Behebung eines Problems, bei dem sich das App-Fenster manchmal ohne Inhalt öffnete, bis man zu einem der Tabs wechselte.
- Behebung eines Problems mit dem "+"-Feld, wo man manchmal keine neue Aktion hinzufügen konnte, obwohl es einen Hover-Effekt zeigte, der anzeigte, dass man eine Aktion eingeben kann.
- Behebung eines Deadlocks und mehrerer anderer kleiner Probleme, die manchmal auftraten, wenn man den Mauszeiger innerhalb des "+"-Feldes bewegte
- Behebung eines Problems, bei dem ein Popover, das auf dem Tasten-Tab erscheint, wenn deine Maus nicht zu den aktuellen Tasteneinstellungen zu passen scheint, manchmal komplett fetten Text hatte.
- Aktualisierung aller Erwähnungen der alten MIT-Lizenz zur neuen MMF-Lizenz. Neue für das Projekt erstellte Dateien werden jetzt einen automatisch generierten Header mit Erwähnung der MMF-Lizenz enthalten.
- Wechsel zum Tasten-Tab aktiviert jetzt MMF fürs Scrollen. Andernfalls konnte man keine Klicken-und-Scrollen-Gesten aufnehmen.
- Behebung einiger Probleme, bei denen Tastennamen in manchen Situationen nicht korrekt in der Aktions-Tabelle angezeigt wurden.
- Behebung eines Fehlers, bei dem der Trial-Bereich auf dem Über-Bildschirm fehlerhaft aussah, wenn man die App öffnete und dann zum Trial-Tab wechselte, nachdem die Testversion abgelaufen war.
- Behebung eines Fehlers, bei dem der Lizenz-Aktivieren-Link im Trial-Bereich des Über-Tabs manchmal nicht auf Klicks reagierte.
- Behebung eines Speicherlecks bei Verwendung der "Klicken und Ziehen" für "Spaces & Mission Control"-Funktion.
- Aktivierung von Hardened Runtime in der Haupt-Mac-Mouse-Fix-App, verbessert die Sicherheit
- Viel Code-Aufräumarbeit, Projekt-Restrukturierung
- Mehrere andere Abstürze behoben
- Mehrere Speicherlecks behoben
- Verschiedene kleine UI-Text-Anpassungen
- Überarbeitungen mehrerer interner Systeme verbesserten auch die Robustheit und das Verhalten in Randfällen

## 8. Wie du helfen kannst

Du kannst helfen, indem du deine **Ideen**, **Probleme** und **Feedback** teilst!

Der beste Ort, um deine **Ideen** und **Probleme** zu teilen, ist der [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Der beste Ort für **schnelles** unstrukturiertes Feedback ist die [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Du kannst diese Orte auch von innerhalb der App auf dem "**ⓘ Über**" Tab erreichen.

**Danke**, dass du hilfst, Mac Mouse Fix so gut wie möglich zu machen! 🙌:)