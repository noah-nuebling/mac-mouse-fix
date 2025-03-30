Mac Mouse Fix **2.2.1** bietet vollständige **Unterstützung für macOS Ventura** und weitere Änderungen.

### Ventura-Unterstützung!
Mac Mouse Fix unterstützt jetzt macOS 13 Ventura vollständig und fühlt sich darauf natürlich an.
Besonderer Dank geht an [@chamburr](https://github.com/chamburr), der bei der Ventura-Unterstützung im GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297) geholfen hat.

Änderungen beinhalten:

- Aktualisierte Benutzeroberfläche für die Gewährung des Zugriffs auf Bedienungshilfen, um die neuen Ventura Systemeinstellungen widerzuspiegeln
- Mac Mouse Fix wird nun korrekt unter Venturas neuem Menü **Systemeinstellungen > Anmeldeobjekte** angezeigt
- Mac Mouse Fix reagiert nun korrekt, wenn es unter **Systemeinstellungen > Anmeldeobjekte** deaktiviert wird

### Einstellung der Unterstützung für ältere macOS-Versionen

Leider erlaubt Apple nur die Entwicklung _für_ macOS 10.13 **High Sierra und neuer**, wenn man _von_ macOS 13 Ventura aus entwickelt.

Die **Mindestversion** wurde daher von 10.11 El Capitan auf 10.13 High Sierra angehoben.

### Fehlerbehebungen

- Ein Problem wurde behoben, bei dem Mac Mouse Fix das Scrollverhalten einiger **Zeichentabletts** veränderte. Siehe GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Ein Problem wurde behoben, bei dem **Tastaturkurzbefehle** mit der Taste 'A' nicht aufgezeichnet werden konnten. Behebt GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Ein Problem wurde behoben, bei dem einige **Tastenzuweisungen** bei Verwendung eines nicht-standardmäßigen Tastaturlayouts nicht richtig funktionierten.
- Ein Absturz in '**App-spezifische Einstellungen**' wurde behoben, der beim Versuch auftrat, eine App ohne 'Bundle ID' hinzuzufügen. Könnte bei GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289) helfen.
- Ein Absturz wurde behoben, der beim Versuch auftrat, Apps ohne Namen zu '**App-spezifische Einstellungen**' hinzuzufügen. Löst GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Besonderer Dank an [jeongtae](https://github.com/jeongtae), der bei der Problemfindung sehr hilfreich war!
- Weitere kleine Fehlerbehebungen und Verbesserungen unter der Haube.