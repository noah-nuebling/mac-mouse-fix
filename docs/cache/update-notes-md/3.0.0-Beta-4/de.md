Sieh dir auch an, **was neu war** in [3.0.0 Beta 3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-3)!

---

**3.0.0 Beta 4** bringt eine neue **"Standardeinstellungen wiederherstellen..." Option** sowie viele **Verbesserungen** der **Benutzerfreundlichkeit** und **Fehlerbehebungen**!

Hier ist **alles**, was **neu** ist:

## 1. "Standardeinstellungen wiederherstellen..." Option

Es gibt jetzt einen "**Standardeinstellungen wiederherstellen...**" Button im "Tasten" Tab.
Damit kannst du dich beim **Experimentieren** mit den Einstellungen noch **sicherer** fühlen.

Es gibt **2 Standardeinstellungen**:

1. Die "Standardeinstellung für Mäuse mit **5+ Tasten**" ist super leistungsfähig und komfortabel. Sie ermöglicht dir tatsächlich **alles**, was du auf einem **Trackpad** machst. Alles mit den 2 **Seitentasten**, die genau dort sind, wo dein **Daumen** ruht! Aber natürlich ist sie nur für Mäuse mit 5 oder mehr Tasten verfügbar.
2. Die "Standardeinstellung für Mäuse mit **3 Tasten**" ermöglicht dir immer noch die **wichtigsten** Trackpad-Funktionen - selbst auf einer Maus mit nur 3 Tasten.

Ich habe mich bemüht, diese Funktion **intelligent** zu gestalten:

- Wenn du MMF zum ersten Mal startest, wird **automatisch** die Voreinstellung ausgewählt, die **am besten zu deiner Maus passt**.
- Wenn du die Standardeinstellungen wiederherstellst, zeigt dir Mac Mouse Fix an, welches **Mausmodell** du verwendest und wie viele **Tasten** es hat, damit du leicht entscheiden kannst, welche der beiden Voreinstellungen du verwenden möchtest. Die Voreinstellung, die **am besten zu deiner Maus passt**, wird dabei **vorausgewählt**.
- Wenn du zu einer **neuen Maus** wechselst, die nicht zu deinen aktuellen Einstellungen passt, erinnert dich ein Popup im Tasten-Tab daran, wie du die **empfohlenen Einstellungen** für deine Maus **laden** kannst!
- Die gesamte **Benutzeroberfläche** dafür ist sehr **einfach**, **schön** und **animiert** gut.

Ich hoffe, du findest diese Funktion **nützlich** und **einfach zu bedienen**! Aber lass es mich wissen, wenn du Probleme hast.
Ist etwas **seltsam** oder **nicht intuitiv**? Erscheinen die **Popups** zu **häufig** oder in **unpassenden Situationen**? **Erzähl mir** von deinen Erfahrungen!

## 2. Mac Mouse Fix vorübergehend kostenlos in einigen Ländern

Es gibt einige **Länder**, in denen der **Zahlungsanbieter** Gumroad von Mac Mouse Fix derzeit **nicht funktioniert**.
Mac Mouse Fix ist jetzt in **diesen Ländern** **kostenlos**, bis ich eine alternative Zahlungsmethode anbieten kann!

Wenn du in einem der kostenlosen Länder bist, werden Informationen darüber im **About-Tab** und beim **Eingeben eines Lizenzschlüssels** **angezeigt**.

Wenn es in deinem Land **unmöglich ist**, Mac Mouse Fix zu kaufen, es aber auch noch **nicht kostenlos** ist - lass es mich wissen und ich mache Mac Mouse Fix auch in deinem Land kostenlos!

## 3. Ein guter Zeitpunkt zum Übersetzen!

Mit Beta 4 habe ich **alle UI-Änderungen** implementiert, die ich für Mac Mouse Fix 3 geplant habe. Ich erwarte daher keine großen Änderungen an der Benutzeroberfläche mehr bis zum Release von Mac Mouse Fix 3.

Wenn du bisher gezögert hast, weil du erwartet hast, dass sich die UI noch ändern würde, dann ist **jetzt ein guter Zeitpunkt**, um mit der **Übersetzung** der App in deine Sprache zu beginnen!

**Weitere Informationen** zur Übersetzung der App findest du in den **[3.0.0 Beta 1 Release Notes](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-1.1) > 9. Internationalization**

## 4. Alles Weitere

Neben den oben aufgeführten Änderungen enthält Beta 4 viele weitere kleine **Fehlerbehebungen**, **Anpassungen** und **Verbesserungen** der Benutzerfreundlichkeit:

### UI

#### Fehlerbehebungen

- Fehler behoben, bei dem sich Links vom About-Tab immer wieder öffneten, wenn man irgendwo im Fenster klickte. Dank an GitHub-Nutzer [DingoBits](https://github.com/DingoBits), der dies behoben hat!
- Fehler behoben, bei dem einige App-Symbole auf älteren macOS-Versionen nicht korrekt angezeigt wurden
- Scrollbalken in der Aktionstabelle versteckt. Danke an GitHub-Nutzer [marianmelinte93](https://github.com/marianmelinte93), der mich in [diesem Kommentar](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366#discussioncomment-3728994) auf dieses Problem aufmerksam gemacht hat!
- Problem behoben, bei dem Feedback über automatisch wieder aktivierte Funktionen beim Öffnen des entsprechenden Tabs in der UI (nachdem die jeweilige Funktion aus der Menüleiste deaktiviert wurde) auf macOS Monterey und älter nicht angezeigt wurde. Nochmals Danke an [marianmelinte93](https://github.com/marianmelinte93) für den Hinweis auf das Problem.
- Fehlende Lokalisierbarkeit und deutsche Übersetzungen für die Option "Klicken zum Scrollen zwischen Spaces" hinzugefügt
- Weitere kleine Lokalisierungsprobleme behoben
- Weitere fehlende deutsche Übersetzungen hinzugefügt
- Benachrichtigungen, die anzeigen, wenn eine Taste erfasst / nicht mehr erfasst wird, funktionieren jetzt richtig, wenn einige Tasten gleichzeitig erfasst und andere nicht mehr erfasst wurden.

#### Verbesserungen

- Option "Klicken und Scrollen für App-Switcher" entfernt. Sie war etwas fehlerhaft und ich denke nicht, dass sie sehr nützlich war.
- Option "Klicken und Scrollen zum Rotieren" hinzugefügt.
- Layout des "Mac Mouse Fix" Menüs in der Menüleiste überarbeitet.
- "Mac Mouse Fix kaufen" Button zum "Mac Mouse Fix" Menü in der Menüleiste hinzugefügt.
- Hinweistext unter der Option "In Menüleiste anzeigen" hinzugefügt. Ziel ist es, besser erkennbar zu machen, dass das Menüleisten-Item zum schnellen Ein- und Ausschalten von Funktionen verwendet werden kann
- Die "Danke für den Kauf von Mac Mouse Fix" Nachrichten im About-Bildschirm können jetzt vollständig von Übersetzern angepasst werden.
- Verbesserte Hinweise für Übersetzer
- Verbesserte UI-Texte rund um den Ablauf der Testversion
- Verbesserte UI-Texte im About-Tab
- Fettgedruckte Hervorhebungen zu einigen UI-Texten hinzugefügt, um die Lesbarkeit zu verbessern
- Warnung hinzugefügt beim Klicken auf den "Schick mir eine E-Mail" Link im About-Tab.
- Sortierreihenfolge der Aktionstabelle geändert. Klick- und Scroll-Aktionen werden jetzt vor Klick- und Zieh-Aktionen angezeigt. Das fühlt sich für mich natürlicher an, da die Zeilen der Tabelle nun nach der Stärke ihrer Auslöser sortiert sind (Klick < Scroll < Ziehen).
- Die App aktualisiert jetzt das aktiv verwendete Gerät bei der Interaktion mit der UI. Das ist nützlich, da einige UI-Elemente jetzt auf dem Gerät basieren, das du verwendest. (Siehe die neue "Standardeinstellungen wiederherstellen..." Funktion).
- Eine Benachrichtigung, die anzeigt, welche Tasten erfasst wurden / nicht mehr erfasst sind, wird jetzt beim ersten Start der App angezeigt.
- Weitere Verbesserungen an Benachrichtigungen, die anzeigen, wenn eine Taste erfasst wurde / nicht mehr erfasst ist
- Unmöglich gemacht, versehentlich zusätzliche Leerzeichen bei der Aktivierung eines Lizenzschlüssels einzugeben

### Maus

#### Fehlerbehebungen

- Verbesserte Scroll-Simulation, um "fixed point deltas" korrekt zu senden. Dies löst ein Problem, bei dem die Scrollgeschwindigkeit in einigen Apps wie Safari bei ausgeschaltetem sanften Scrollen zu langsam war.
- Problem behoben, bei dem die Funktion "Klicken und Ziehen für Mission Control & Spaces" manchmal hängen blieb, wenn der Computer langsam war
- Problem behoben, bei dem die CPU von Mac Mouse Fix immer genutzt wurde, wenn man die Maus nach Verwendung der Funktion "Klicken und Ziehen zum Scrollen & Navigieren" bewegte

#### Verbesserungen

- Deutlich verbesserte Scroll-zu-Zoom Reaktionsfähigkeit in Chromium-basierten Browsern wie Chrome, Brave oder Edge

### Unter der Haube

#### Fehlerbehebungen

- Problem behoben, bei dem Mac Mouse Fix nicht richtig funktionierte, nachdem es in einen anderen Ordner verschoben wurde, während es aktiviert war
- Einige Probleme beim Aktivieren von Mac Mouse Fix behoben, während eine andere Instanz von Mac Mouse Fix noch aktiviert war. (Das liegt daran, dass Apple mir erlaubt hat, die Bundle-ID von "com.nuebling.mac-mouse-fixxx", die in Beta 3 verwendet wurde, zurück zur ursprünglichen "com.nuebling.mac-mouse-fix" zu ändern. Weiß nicht warum.)

#### Verbesserungen

- Diese und zukünftige Betas werden detailliertere Debug-Informationen ausgeben
- Aufräumarbeiten und Verbesserungen unter der Haube. Alter Pre-10.13-Code entfernt. Frameworks und Abhängigkeiten aufgeräumt. Der Quellcode ist jetzt einfacher zu bearbeiten und zukunftssicherer.