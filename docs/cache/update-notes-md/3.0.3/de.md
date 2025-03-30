**ℹ️ Hinweis für Mac Mouse Fix 2 Nutzer**

Mit der Einführung von Mac Mouse Fix 3 hat sich das Preismodell der App geändert:

- **Mac Mouse Fix 2**\
Bleibt zu 100% kostenlos und ich plane, es weiterhin zu unterstützen.\
**Überspringe dieses Update**, um Mac Mouse Fix 2 weiter zu nutzen. Lade die neueste Version von Mac Mouse Fix 2 [hier](https://redirect.macmousefix.com/?target=mmf2-latest) herunter.
- **Mac Mouse Fix 3**\
30 Tage kostenlos, kostet dann ein paar Euro zum Kauf.\
**Jetzt updaten**, um Mac Mouse Fix 3 zu erhalten!

Mehr über die Preise und Funktionen von Mac Mouse Fix 3 erfährst du auf der [neuen Website](https://macmousefix.com/).

Danke, dass du Mac Mouse Fix nutzt! :)

---

**ℹ️ Hinweis für Mac Mouse Fix 3 Käufer**

Falls du versehentlich auf Mac Mouse Fix 3 aktualisiert hast, ohne zu wissen, dass es nicht mehr kostenlos ist, möchte ich dir eine [Rückerstattung](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) anbieten.

Die neueste Version von Mac Mouse Fix 2 bleibt **komplett kostenlos** und du kannst sie [hier](https://redirect.macmousefix.com/?target=mmf2-latest) herunterladen.

Tut mir leid für die Umstände, und ich hoffe, diese Lösung ist für alle in Ordnung!

---

Mac Mouse Fix **3.0.3** ist bereit für macOS 15 Sequoia. Es behebt auch einige Stabilitätsprobleme und bringt mehrere kleine Verbesserungen.

### macOS 15 Sequoia Unterstützung

Die App funktioniert jetzt einwandfrei unter macOS 15 Sequoia!

- Die meisten UI-Animationen waren unter macOS 15 Sequoia defekt. Jetzt funktioniert wieder alles richtig!
- Der Quellcode lässt sich jetzt unter macOS 15 Sequoia kompilieren. Zuvor gab es Probleme mit dem Swift-Compiler, die das Kompilieren verhinderten.

### Behebung von Scroll-Abstürzen

Seit Mac Mouse Fix 3.0.2 gab es [mehrere Berichte](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) darüber, dass sich Mac Mouse Fix beim Scrollen periodisch deaktivierte und wieder aktivierte. Dies wurde durch Abstürze der 'Mac Mouse Fix Helper' Hintergrund-App verursacht. Dieses Update versucht, diese Abstürze mit folgenden Änderungen zu beheben:

- Der Scroll-Mechanismus wird versuchen, sich zu erholen und weiterzulaufen, anstatt abzustürzen, wenn er auf den Grenzfall trifft, der zu diesen Abstürzen geführt zu haben scheint.
- Ich habe die Art und Weise geändert, wie unerwartete Zustände in der App generell behandelt werden: Anstatt sofort abzustürzen, wird die App nun in vielen Fällen versuchen, sich von unerwarteten Zuständen zu erholen.

    - Diese Änderung trägt zu den oben beschriebenen Fixes für die Scroll-Abstürze bei. Sie könnte auch andere Abstürze verhindern.

Nebenbemerkung: Ich konnte diese Abstürze auf meinem Rechner nie reproduzieren und bin mir immer noch nicht sicher, was sie verursacht hat. Aber basierend auf den erhaltenen Berichten sollte dieses Update alle Abstürze verhindern. Wenn du weiterhin Abstürze beim Scrollen erlebst oder wenn du unter 3.0.2 Abstürze erlebt hast, wäre es wertvoll, wenn du deine Erfahrungen und Diagnosedaten im GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) teilst. Das würde mir helfen, das Problem zu verstehen und Mac Mouse Fix zu verbessern. Danke!

### Behebung von Scroll-Stottern

In 3.0.2 habe ich Änderungen daran vorgenommen, wie Mac Mouse Fix Scroll-Events an das System sendet, um Scroll-Stottern zu reduzieren, das wahrscheinlich durch Probleme mit Apples VSync-APIs verursacht wurde.

Nach ausführlicheren Tests und Feedback scheint der neue Mechanismus in 3.0.2 das Scrollen in manchen Szenarien zwar flüssiger zu machen, in anderen aber stotternder. Besonders in Firefox schien es merklich schlechter zu sein.\
Insgesamt war nicht klar, ob der neue Mechanismus das Scroll-Stottern wirklich durchgängig verbesserte. Außerdem könnte er zu den oben beschriebenen Scroll-Abstürzen beigetragen haben.

Deshalb habe ich den neuen Mechanismus deaktiviert und den VSync-Mechanismus für Scroll-Events wieder auf den Stand von Mac Mouse Fix 3.0.0 und 3.0.1 zurückgesetzt.

Mehr Informationen findest du im GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875).

### Rückerstattung

Es tut mir leid für die Probleme im Zusammenhang mit den Scroll-Änderungen in 3.0.1 und 3.0.2. Ich habe die Probleme, die damit einhergehen würden, stark unterschätzt und war langsam darin, diese Probleme anzugehen. Ich werde mein Bestes geben, aus dieser Erfahrung zu lernen und in Zukunft vorsichtiger mit solchen Änderungen umzugehen. Ich möchte auch allen Betroffenen eine Rückerstattung anbieten. Klicke einfach [hier](https://redirect.macmousefix.com/?target=mmf-apply-for-refund), wenn du interessiert bist.

### Intelligenterer Update-Mechanismus

Diese Änderungen wurden von Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) und [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5) übernommen. Schau dir deren Release Notes an, um mehr über die Details zu erfahren. Hier eine Zusammenfassung:

- Es gibt einen neuen, intelligenteren Mechanismus, der entscheidet, welches Update dem Nutzer angezeigt wird.
- Wechsel vom Sparkle 1.26.0 Update-Framework zur neuesten Version Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- Das Fenster, das die App anzeigt, um dich über eine neue Version von Mac Mouse Fix zu informieren, unterstützt jetzt JavaScript, was eine schönere Formatierung der Update-Hinweise ermöglicht.

### Weitere Verbesserungen & Fehlerbehebungen

- Ein Problem wurde behoben, bei dem der App-Preis und zugehörige Informationen im 'Über'-Tab in manchen Fällen falsch angezeigt wurden.
- Ein Problem wurde behoben, bei dem der Mechanismus zur Synchronisation des sanften Scrollens mit der Bildwiederholrate bei der Verwendung mehrerer Bildschirme nicht richtig funktionierte.
- Viele kleine Verbesserungen und Aufräumarbeiten unter der Haube.

---

Schau dir auch das vorherige Release [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2) an.