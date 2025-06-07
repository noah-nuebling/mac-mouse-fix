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

Mac Mouse Fix **3.0.4** verbessert Datenschutz, Effizienz und Zuverlässigkeit.\
Es führt ein neues Offline-Lizenzsystem ein und behebt mehrere wichtige Fehler.

### Verbesserter Datenschutz & Effizienz

3.0.4 führt ein neues Offline-Lizenzvalidierungssystem ein, das Internetverbindungen auf ein Minimum reduziert.\
Dies verbessert den Datenschutz und schont die Systemressourcen deines Computers.\
Nach der Lizenzierung arbeitet die App jetzt zu 100% offline!

<details>
<summary><b>Hier klicken für mehr Details</b></summary>
Frühere Versionen validierten Lizenzen bei jedem Start online, wodurch Verbindungsprotokolle möglicherweise auf Servern von Drittanbietern (GitHub und Gumroad) gespeichert werden konnten. Das neue System eliminiert unnötige Verbindungen – nach der ersten Lizenzaktivierung verbindet es sich nur noch mit dem Internet, wenn lokale Lizenzdaten beschädigt sind.
<br><br>
Auch wenn ich persönlich nie Nutzerverhalten aufgezeichnet habe, ermöglichte das vorherige System theoretisch Drittanbieter-Servern, IP-Adressen und Verbindungszeiten zu protokollieren. Gumroad konnte auch deinen Lizenzschlüssel protokollieren und ihn möglicherweise mit persönlichen Informationen verknüpfen, die sie beim Kauf von Mac Mouse Fix über dich gespeichert haben.
<br><br>
Diese subtilen Datenschutzprobleme hatte ich beim Aufbau des ursprünglichen Lizenzsystems nicht bedacht, aber jetzt ist Mac Mouse Fix so privat und internetfrei wie möglich!
<br><br>
Siehe auch <a href=https://gumroad.com/privacy>Gumroads Datenschutzerklärung</a> und meinen <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub-Kommentar</a>.

</details>

### Fehlerbehebungen

- Ein Fehler wurde behoben, bei dem macOS manchmal hängen blieb, wenn 'Klicken und Ziehen' für 'Spaces & Mission Control' verwendet wurde.
- Ein Fehler wurde behoben, bei dem Tastaturkurzbefehle in den Systemeinstellungen manchmal gelöscht wurden, wenn Mac Mouse Fix 'Klick'-Aktionen wie 'Mission Control' verwendet wurden.
- Ein [Fehler](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) wurde behoben, bei dem die App manchmal nicht mehr funktionierte und Nutzern, die die App bereits gekauft hatten, eine Benachrichtigung anzeigte, dass die 'kostenlosen Tage vorbei' seien.
    - Falls du von diesem Fehler betroffen warst, entschuldige ich mich aufrichtig für die Unannehmlichkeiten. Du kannst [hier eine Rückerstattung beantragen](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Die Art und Weise, wie die Anwendung ihr Hauptfenster abruft, wurde verbessert, was möglicherweise einen Fehler behoben hat, bei dem der 'Lizenz aktivieren'-Bildschirm manchmal nicht erschien.

### Verbesserungen der Benutzerfreundlichkeit

- Es wurde unmöglich gemacht, Leerzeichen und Zeilenumbrüche im Textfeld auf dem 'Lizenz aktivieren'-Bildschirm einzugeben.
    - Dies war ein häufiger Verwirrungspunkt, da es sehr leicht ist, versehentlich einen versteckten Zeilenumbruch auszuwählen, wenn man seinen Lizenzschlüssel aus Gumroads E-Mails kopiert.
- Diese Update-Hinweise werden für nicht-englischsprachige Nutzer automatisch übersetzt (unterstützt durch Claude). Ich hoffe, das ist hilfreich! Falls du Probleme damit bemerkst, lass es mich wissen. Dies ist ein erster Einblick in ein neues Übersetzungssystem, an dem ich im letzten Jahr gearbeitet habe.

### Eingestellte (inoffizielle) Unterstützung für macOS 10.14 Mojave

Mac Mouse Fix 3 unterstützt offiziell macOS 11 Big Sur und höher. Allerdings konnte Mac Mouse Fix 3.0.3 und frühere Versionen von Nutzern, die bereit waren, einige Fehler und grafische Probleme zu akzeptieren, noch auf macOS 10.14.4 Mojave verwendet werden.

Mac Mouse Fix 3.0.4 stellt diese Unterstützung ein und **erfordert nun macOS 10.15 Catalina**.\
Ich entschuldige mich für eventuelle Unannehmlichkeiten. Diese Änderung ermöglichte es mir, das verbesserte Lizenzsystem mit modernen Swift-Funktionen zu implementieren. Mojave-Nutzer können weiterhin Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) oder die [neueste Version von Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest) verwenden. Ich hoffe, das ist für alle eine gute Lösung.

### Verbesserungen unter der Haube

- Ein neues 'MFDataClass'-System wurde implementiert, das eine leistungsfähigere Datenmodellierung ermöglicht, während die Konfigurationsdatei von Mac Mouse Fix weiterhin für Menschen lesbar und bearbeitbar bleibt.
- Unterstützung für weitere Zahlungsplattformen neben Gumroad wurde eingebaut. In Zukunft könnte es also lokalisierte Checkouts geben, und die App könnte in verschiedenen Ländern verkauft werden.
- Verbessertes Logging, das es mir ermöglicht, effektivere "Debug Builds" für Nutzer zu erstellen, die schwer reproduzierbare Fehler erleben.
- Viele weitere kleine Verbesserungen und Aufräumarbeiten.

*Bearbeitet mit hervorragender Unterstützung von Claude.*

---

Sieh dir auch das vorherige Release [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) an.