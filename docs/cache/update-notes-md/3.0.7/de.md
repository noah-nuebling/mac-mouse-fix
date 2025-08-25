Mac Mouse Fix **3.0.7** behebt mehrere wichtige Fehler.

### Fehlerbehebungen

- App funktioniert wieder unter **älteren macOS-Versionen** (macOS 10.15 Catalina und macOS 11 Big Sur)
    - Mac Mouse Fix 3.0.6 konnte unter diesen macOS-Versionen nicht aktiviert werden, da die verbesserte 'Zurück' und 'Vorwärts' Funktion in Mac Mouse Fix 3.0.6 versuchte, macOS System-APIs zu verwenden, die nicht verfügbar waren.
- Probleme mit der **'Zurück' und 'Vorwärts'** Funktion behoben
    - Die in Mac Mouse Fix 3.0.6 eingeführte verbesserte 'Zurück' und 'Vorwärts' Funktion wird nun immer den 'Hauptthread' verwenden, um macOS nach den zu simulierenden Tastatureingaben für Vor- und Zurücknavigation in der verwendeten App zu fragen. \
    Dies kann Abstürze und unzuverlässiges Verhalten in manchen Situationen verhindern.
- Versuch, einen Fehler zu beheben, bei dem **Einstellungen zufällig zurückgesetzt wurden** (Siehe diese [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Ich habe den Code zum Laden der Konfigurationsdatei für Mac Mouse Fix robuster umgeschrieben. Bei seltenen macOS-Dateisystem-Fehlern konnte der alte Code manchmal fälschlicherweise annehmen, dass die Konfigurationsdatei beschädigt sei und setzte sie auf die Standardeinstellungen zurück.
- Reduzierte Wahrscheinlichkeit eines Fehlers, bei dem **das Scrollen nicht mehr funktioniert**
    - Dieser Fehler kann ohne tiefgreifendere Änderungen, die wahrscheinlich andere Probleme verursachen würden, nicht vollständig gelöst werden. \
    Allerdings habe ich vorerst das Zeitfenster reduziert, in dem ein 'Deadlock' im Scrollsystem auftreten kann, was zumindest die Wahrscheinlichkeit verringern sollte, auf diesen Fehler zu stoßen. Dies macht das Scrollen auch etwas effizienter.
    - Dieser Fehler hat ähnliche Symptome – aber ich denke einen anderen zugrundeliegenden Grund – wie der 'Scroll funktioniert zeitweise nicht' Fehler, der in der letzten Version 3.0.6 behoben wurde.
    - (Danke an Joonas für das Feedback!)

Danke an alle fürs Melden der Fehler!

---

Schau dir auch die vorherige Version [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6) an.