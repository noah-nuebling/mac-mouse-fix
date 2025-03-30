Mac Mouse Fix **3.0.4 Beta 1** verbessert Datenschutz, Effizienz und Zuverlässigkeit.\
Es führt ein neues Offline-Lizenzsystem ein und behebt mehrere wichtige Fehler.

### Verbesserter Datenschutz & Effizienz

- Führt ein neues Offline-Lizenzvalidierungssystem ein, das Internetverbindungen minimiert.
- Die App verbindet sich nur noch dann mit dem Internet, wenn es absolut notwendig ist, was deinen Datenschutz schützt und den Ressourcenverbrauch reduziert.
- Die App arbeitet bei vorhandener Lizenz während der normalen Nutzung komplett offline.

<details>
<summary><b>Detaillierte Datenschutzinformationen</b></summary>
Frühere Versionen validierten Lizenzen bei jedem Start online, wodurch Verbindungsprotokolle möglicherweise auf Servern von Drittanbietern (GitHub und Gumroad) gespeichert werden konnten. Das neue System eliminiert unnötige Verbindungen – nach der ersten Lizenzaktivierung verbindet es sich nur noch mit dem Internet, wenn lokale Lizenzdaten beschädigt sind.
<br><br>
Auch wenn ich persönlich nie Nutzerverhalten aufgezeichnet habe, ermöglichte das vorherige System theoretisch Drittanbieter-Servern die Protokollierung von IP-Adressen und Verbindungszeiten. Gumroad konnte auch deinen Lizenzschlüssel protokollieren und ihn möglicherweise mit persönlichen Informationen verknüpfen, die sie beim Kauf von Mac Mouse Fix über dich gespeichert haben.
<br><br>
Diese subtilen Datenschutzprobleme hatte ich beim Aufbau des ursprünglichen Lizenzsystems nicht bedacht, aber jetzt ist Mac Mouse Fix so privat und internetfrei wie möglich!
<br><br>
Siehe auch <a href=https://gumroad.com/privacy>Gumroads Datenschutzerklärung</a> und meinen <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub-Kommentar</a>.

</details>

### Fehlerbehebungen

- Ein Fehler wurde behoben, bei dem macOS manchmal hängen blieb, wenn 'Klicken und Ziehen' für 'Spaces & Mission Control' verwendet wurde.
- Ein Fehler wurde behoben, bei dem Tastaturkurzbefehle in den Systemeinstellungen manchmal gelöscht wurden, wenn eine in Mac Mouse Fix definierte 'Klick'-Aktion wie 'Mission Control' verwendet wurde.
- Ein [Fehler](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) wurde behoben, bei dem die App manchmal nicht mehr funktionierte und Nutzern, die die App bereits gekauft hatten, eine Benachrichtigung anzeigte, dass die 'kostenlosen Tage vorbei' seien.
    - Falls du von diesem Fehler betroffen warst, entschuldige ich mich aufrichtig für die Unannehmlichkeiten. Du kannst [hier eine Rückerstattung beantragen](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).

### Technische Verbesserungen

- Ein neues 'MFDataClass'-System wurde implementiert, das eine sauberere Datenmodellierung und menschenlesbare Konfigurationsdateien ermöglicht.
- Unterstützung für weitere Zahlungsplattformen neben Gumroad wurde eingebaut. In Zukunft könnte es also lokalisierte Kaufabwicklungen geben und die App könnte in verschiedenen Ländern verkauft werden!

### Einstellung der (inoffiziellen) Unterstützung für macOS 10.14 Mojave

Mac Mouse Fix 3 unterstützt offiziell macOS 11 Big Sur und neuer. Allerdings konnte Mac Mouse Fix 3.0.3 und frühere Versionen von Nutzern, die bereit waren, einige Fehler und grafische Probleme zu akzeptieren, noch unter macOS 10.14.4 Mojave verwendet werden.

Mac Mouse Fix 3.0.4 beendet diese Unterstützung und **erfordert nun macOS 10.15 Catalina**.\
Ich entschuldige mich für eventuelle Unannehmlichkeiten. Diese Änderung ermöglichte es mir, das verbesserte Lizenzsystem mit modernen Swift-Funktionen zu implementieren. Mojave-Nutzer können weiterhin Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) oder die [neueste Version von Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest) verwenden. Ich hoffe, das ist für alle eine gute Lösung.

*Bearbeitet mit hervorragender Unterstützung von Claude.*

---

Sieh dir auch das vorherige Release [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) an.