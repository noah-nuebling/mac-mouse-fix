Mac Mouse Fix **3.0.1** bringt mehrere Fehlerbehebungen und Verbesserungen, sowie eine **neue Sprache**!

### Vietnamesisch wurde hinzugefügt!

Mac Mouse Fix ist jetzt in 🇻🇳 Vietnamesisch verfügbar. Vielen Dank an @nghlt [auf GitHub](https://GitHub.com/nghlt)!


### Fehlerbehebungen

- Mac Mouse Fix funktioniert jetzt einwandfrei mit **Schnellem Benutzer:innenwechsel**!
  - Schneller Benutzer:innenwechsel bedeutet, dass du dich in ein zweites macOS-Konto einloggst, ohne dich vom ersten abzumelden.
  - Vor diesem Update funktionierte das Scrollen nach einem schnellen Benutzer:innenwechsel nicht mehr. Jetzt sollte alles korrekt funktionieren.
- Ein kleiner Fehler wurde behoben, bei dem das Layout des Buttons-Tabs nach dem ersten Start von Mac Mouse Fix zu breit war.
- Das '+'-Feld funktioniert jetzt zuverlässiger beim schnellen Hinzufügen mehrerer Aktionen.
- Ein spezieller Absturz wurde behoben, der von @V-Coba in Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735) gemeldet wurde.

### Weitere Verbesserungen

- **Scrollen fühlt sich reaktionsschneller an** bei der Einstellung 'Geschmeidigkeit: Normal'.
  - Die Animationsgeschwindigkeit wird jetzt schneller, je schneller du das Scrollrad bewegst. Dadurch fühlt es sich reaktionsschneller an, wenn du schnell scrollst, während es genauso geschmeidig bleibt, wenn du langsam scrollst.
  
- Die **Scroll-Geschwindigkeitsbeschleunigung** wurde stabiler und vorhersehbarer gemacht.
- Ein Mechanismus wurde implementiert, um **deine Einstellungen zu behalten**, wenn du auf eine neue Mac Mouse Fix Version aktualisierst.
  - Vorher setzte Mac Mouse Fix alle deine Einstellungen zurück, wenn sich die Struktur der Einstellungen nach einem Update änderte. Jetzt versucht Mac Mouse Fix, die Struktur deiner Einstellungen zu aktualisieren und deine Präferenzen beizubehalten.
  - Bisher funktioniert dies nur beim Update von 3.0.0 auf 3.0.1. Wenn du von einer älteren Version als 3.0.0 aktualisierst oder wenn du von 3.0.1 auf eine frühere Version _herabstufst_, werden deine Einstellungen weiterhin zurückgesetzt.
- Das Layout des Buttons-Tabs passt seine Breite jetzt besser an verschiedene Sprachen an.
- Verbesserungen am [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) und anderen Dokumenten.
- Verbesserte Lokalisierungssysteme. Die Übersetzungsdateien werden jetzt automatisch bereinigt und auf mögliche Probleme analysiert. Es gibt einen neuen [Lokalisierungsleitfaden](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731), der automatisch erkannte Probleme sowie weitere nützliche Informationen und Anweisungen für Personen enthält, die bei der Übersetzung von Mac Mouse Fix helfen möchten. Die Abhängigkeit vom [BartyCrouch](https://github.com/FlineDev/BartyCrouch)-Tool wurde entfernt, das zuvor für einige dieser Funktionen verwendet wurde.
- Verschiedene UI-Texte in Englisch und Deutsch wurden verbessert.
- Viele Verbesserungen und Aufräumarbeiten unter der Haube.

---

Schau dir auch die Release Notes für [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) an - das bisher größte Update für Mac Mouse Fix!