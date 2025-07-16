**ℹ️ Hinweis für Mac Mouse Fix 2 Nutzer**

Mit der Einführung von Mac Mouse Fix 3 hat sich das Preismodell der App geändert:

- **Mac Mouse Fix 2**\
Bleibt zu 100% kostenlos und ich plane, es weiterhin zu unterstützen.\
**Überspringe dieses Update**, um Mac Mouse Fix 2 weiter zu nutzen. Lade die neueste Version von Mac Mouse Fix 2 [hier](https://redirect.macmousefix.com/?target=mmf2-latest) herunter.
- **Mac Mouse Fix 3**\
30 Tage kostenlos, kostet dann ein paar Dollar zum Besitzen.\
**Jetzt updaten**, um Mac Mouse Fix 3 zu erhalten!

Mehr über die Preise und Funktionen von Mac Mouse Fix 3 erfährst du auf der [neuen Website](https://macmousefix.com/).

Danke, dass du Mac Mouse Fix nutzt! :)

---

**ℹ️ Hinweis für Mac Mouse Fix 3 Käufer**

Falls du versehentlich auf Mac Mouse Fix 3 aktualisiert hast, ohne zu wissen, dass es nicht mehr kostenlos ist, möchte ich dir eine [Rückerstattung](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) anbieten.

Die neueste Version von Mac Mouse Fix 2 bleibt **komplett kostenlos** und du kannst sie [hier](https://redirect.macmousefix.com/?target=mmf2-latest) herunterladen.

Tut mir leid für die Umstände, und ich hoffe, diese Lösung ist für alle in Ordnung!

---

Mac Mouse Fix **3.0.5** behebt mehrere Fehler, verbessert die Leistung und fügt der App den letzten Schliff hinzu.\
Es ist auch kompatibel mit macOS 26 Tahoe.

### Verbesserte Simulation des Trackpad-Scrollens

- Das Scrollsystem kann jetzt einen Zwei-Finger-Tipp auf dem Trackpad simulieren, um Apps zum Anhalten des Scrollens zu bewegen.
    - Dies behebt ein Problem beim Ausführen von iPhone- oder iPad-Apps, bei dem das Scrollen oft weiterlief, nachdem der Nutzer es stoppen wollte.
- Inkonsistente Simulation des Abhebens der Finger vom Trackpad wurde behoben.
    - Dies könnte in manchen Situationen zu suboptimalem Verhalten geführt haben.

### macOS 26 Tahoe Kompatibilität

Beim Ausführen der macOS 26 Tahoe Beta ist die App nun nutzbar und die meisten UI-Elemente funktionieren korrekt.

### Leistungsverbesserung

Verbesserte Leistung der Klicken-und-Ziehen zum "Scrollen & Navigieren" Geste.\
In meinen Tests wurde die CPU-Auslastung um ~50% reduziert!

**Hintergrund**

Während der "Scrollen & Navigieren" Geste zeichnet Mac Mouse Fix einen falschen Mauszeiger in einem transparenten Fenster, während der echte Mauszeiger fixiert wird. Dies stellt sicher, dass du weiterhin das UI-Element scrollen kannst, mit dem du begonnen hast, egal wie weit du deine Maus bewegst.\

Die verbesserte Leistung wurde erreicht, indem die standardmäßige macOS-Ereignisverarbeitung für dieses transparente Fenster deaktiviert wurde, die ohnehin nicht genutzt wurde.

### Fehlerbehebungen

- Scrollereignisse von Wacom Zeichentabletts werden jetzt ignoriert.
    - Zuvor verursachte Mac Mouse Fix sprunghaftes Scrollen auf Wacom Tabletts, wie von @frenchie1980 in GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233) berichtet. (Danke!)
    
- Ein Fehler wurde behoben, bei dem der Swift Concurrency Code, der mit dem neuen Lizenzsystem in Mac Mouse Fix 3.0.4 eingeführt wurde, nicht im richtigen Thread lief.
    - Dies verursachte Abstürze unter macOS Tahoe und war wahrscheinlich auch für andere sporadische Fehler beim Lizenzieren verantwortlich.
- Verbesserte Robustheit des Codes zur Dekodierung von Offline-Lizenzen.
    - Dies umgeht ein Problem in Apples APIs, das dazu führte, dass die Offline-Lizenzvalidierung auf meinem Intel Mac Mini immer fehlschlug. Ich vermute, dass dies auf allen Intel Macs passierte und der Grund war, warum der "Kostenlose Tage sind vorbei" Fehler (der bereits in 3.0.4 behoben wurde) für einige Nutzer weiterhin auftrat, wie von @toni20k5267 in GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356) berichtet. (Danke!)

### UX-Verbesserungen

- Dialoge deaktiviert, die schrittweise Lösungen für macOS-Fehler anboten, die Nutzer daran hinderten, Mac Mouse Fix zu aktivieren.
    - Diese Probleme traten nur unter macOS 13 Ventura und 14 Sonoma auf. Jetzt erscheinen diese Dialoge nur noch in den macOS-Versionen, wo sie relevant sind.
    - Die Dialoge sind auch etwas schwieriger auszulösen – zuvor erschienen sie manchmal in Situationen, wo sie nicht sehr hilfreich waren.
    
- Ein "Lizenz aktivieren" Link wurde direkt auf der "Kostenlose Tage sind vorbei" Benachrichtigung hinzugefügt.
    - Dies macht die Aktivierung einer Mac Mouse Fix Lizenz noch einfacher und angenehmer.

### Visuelle Verbesserungen

- Leicht verbessertes Aussehen des "Software Update" Fensters. Es passt jetzt besser zu macOS 26 Tahoe.
    - Dies wurde durch Anpassung des Standard-Aussehens des "Sparkle 1.27.3" Frameworks erreicht, das Mac Mouse Fix für Updates verwendet.
- Problem behoben, bei dem der Text am unteren Rand des About-Tabs in Chinesisch manchmal abgeschnitten wurde, indem das Fenster etwas breiter gemacht wurde.
- Zentrierung des Textes am unteren Rand des About-Tabs korrigiert.
- Einen Fehler behoben, der dazu führte, dass der Platz unter der "Tastaturkürzel..." Option im Buttons-Tab zu klein war.

### Unter-der-Haube Änderungen

- Abhängigkeit vom "SnapKit" Framework entfernt
    - Dies reduziert die Größe der App leicht von 19,8 auf 19,5 MB
- Verschiedene andere kleine Verbesserungen im Programmcode.

*Bearbeitet mit hervorragender Unterstützung von Claude.*

---

Sieh dir auch das vorherige Release [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4) an.