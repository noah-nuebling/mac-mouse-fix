Schau dir auch die **tollen Verbesserungen** in [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6) an!


---

**3.0.0 Beta 7** bringt mehrere kleine Verbesserungen und Fehlerbehebungen.

Hier ist alles Neue:

**Verbesserungen**

- **Koreanische Übersetzungen** hinzugefügt. Vielen Dank an @jeongtae! (Finde ihn auf [GitHub](https://github.com/jeongtae))
- **Scrollen** mit der Option 'Geschmeidigkeit: Hoch' wurde **noch geschmeidiger** gemacht, indem die Geschwindigkeit nur allmählich geändert wird, statt plötzlicher Geschwindigkeitssprünge beim Drehen des Scrollrads. Das sollte das Scrollen etwas geschmeidiger und leichter mit den Augen verfolgbar machen, ohne die Reaktionszeit zu beeinträchtigen. Scrollen mit 'Geschmeidigkeit: Hoch' verwendet jetzt etwa 30% mehr CPU, auf meinem Computer stieg es von 1,2% CPU-Auslastung beim kontinuierlichen Scrollen auf 1,6%. Das Scrollen ist also immer noch sehr effizient und ich hoffe, dass dies für niemanden einen Unterschied macht. Großen Dank an [MOS](https://mos.caldis.me/), das diese Funktion inspiriert hat und dessen 'Scroll Monitor' ich bei der Implementierung genutzt habe.
- Mac Mouse Fix **verarbeitet jetzt Tasteneingaben aus allen Quellen**. Zuvor hat Mac Mouse Fix nur Eingaben von erkannten Mäusen verarbeitet. Ich denke, das könnte die Kompatibilität mit bestimmten Mäusen in Randfällen verbessern, zum Beispiel bei Verwendung eines Hackintosh, aber es wird auch dazu führen, dass Mac Mouse Fix künstlich erzeugte Tasteneingaben von anderen Apps aufnimmt, was in anderen Randfällen zu Problemen führen könnte. Lass es mich wissen, wenn dies zu Problemen führt, und ich werde das in zukünftigen Updates angehen.
- Das Gefühl und die Verfeinerung der 'Klicken und Scrollen'-Gesten für 'Desktop & Launchpad' und 'Klicken und Scrollen' zum 'Bewegen zwischen Spaces' wurden verbessert.
- Berücksichtigt jetzt die Informationsdichte einer Sprache bei der Berechnung der **Anzeigedauer von Benachrichtigungen**. Zuvor waren Benachrichtigungen in Sprachen mit hoher Informationsdichte wie Chinesisch oder Koreanisch nur sehr kurz sichtbar.
- Ermöglicht **verschiedene Gesten** zum Bewegen zwischen **Spaces**, Öffnen von **Mission Control** oder Öffnen von **App Exposé**. In Beta 6 hatte ich diese Aktionen versuchsweise nur über die 'Klicken und Ziehen'-Geste verfügbar gemacht, um zu sehen, wie viele Menschen tatsächlich Wert darauf legen, diese Aktionen auf andere Weise aufrufen zu können. Es scheint, dass einige das tun, also habe ich es wieder möglich gemacht, diese Aktionen durch einfaches 'Klicken' einer Taste oder durch 'Klicken und Scrollen' aufzurufen.
- Es ist jetzt möglich, durch eine **Klicken und Scrollen**-Geste zu **Rotieren**.
- Die Funktionsweise der **Trackpad-Simulation**-Option wurde in einigen Szenarien **verbessert**. Zum Beispiel ist beim horizontalen Scrollen zum Löschen einer Nachricht in Mail die Richtung, in die sich die Nachricht bewegt, jetzt umgekehrt, was sich hoffentlich für die meisten Leute natürlicher und konsistenter anfühlt.
- Eine Funktion zum **Neuzuweisen** von **Primärklick** oder **Sekundärklick** wurde hinzugefügt. Ich habe dies implementiert, weil die rechte Maustaste meiner Lieblingsmaus kaputt ging. Diese Optionen sind standardmäßig ausgeblendet. Du kannst sie sehen, indem du die Option-Taste gedrückt hältst, während du eine Aktion auswählst.
  - Hierfür fehlen derzeit Übersetzungen für Chinesisch und Koreanisch. Wenn du Übersetzungen für diese Funktionen beisteuern möchtest, wäre das sehr willkommen!

**Fehlerbehebungen**

- Ein Fehler wurde behoben, bei dem die **Richtung von 'Klicken und Ziehen'** für 'Mission Control & Spaces' für Benutzer **invertiert** war, die nie die Option 'Natürliches Scrollen' in den Systemeinstellungen umgeschaltet haben. Jetzt sollte die Richtung von 'Klicken und Ziehen'-Gesten in Mac Mouse Fix immer der Richtung von Gesten auf deinem Trackpad oder deiner Magic Mouse entsprechen. Wenn du eine separate Option zum Invertieren der 'Klicken und Ziehen'-Richtung möchtest, anstatt dass sie den Systemeinstellungen folgt, lass es mich wissen.
- Ein Fehler wurde behoben, bei dem die **kostenlosen Tage** bei einigen Benutzern **zu schnell hochgezählt** wurden. Wenn du davon betroffen warst, lass es mich wissen und ich schaue, was ich tun kann.
- Ein Problem unter macOS Sonoma wurde behoben, bei dem die Tab-Leiste nicht richtig angezeigt wurde.
- Ruckeln beim Verwenden der 'macOS'-Scrollgeschwindigkeit während der Verwendung von 'Klicken und Scrollen' zum Öffnen von Launchpad wurde behoben.
- Ein Absturz wurde behoben, bei dem die 'Mac Mouse Fix Helper'-App (die im Hintergrund läuft, wenn Mac Mouse Fix aktiviert ist) manchmal beim Aufzeichnen eines Tastaturkürzels abstürzte.
- Ein Fehler wurde behoben, bei dem Mac Mouse Fix abstürzte, wenn versucht wurde, künstliche Events von [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma) aufzunehmen.
- Ein Problem wurde behoben, bei dem der Name einiger Mäuse im 'Standardeinstellungen wiederherstellen...'-Dialog den Hersteller zweimal enthielt.
- Es wurde unwahrscheinlicher gemacht, dass 'Klicken und Ziehen' für 'Mission Control & Spaces' hängen bleibt, wenn der Computer langsam ist.
- Die Verwendung von 'Force Touch' in UI-Texten wurde korrigiert, wo es 'Force click' heißen sollte.
- Ein Fehler wurde behoben, der bei bestimmten Konfigurationen auftrat, bei denen das Öffnen von Launchpad oder das Anzeigen des Desktops durch 'Klicken und Scrollen' nicht funktionierte, wenn die Taste losgelassen wurde, während die Übergangsanimation noch lief.

**Mehr**

- Verschiedene Verbesserungen unter der Haube, Stabilitätsverbesserungen, Aufräumarbeiten unter der Haube und mehr.

## Wie du helfen kannst

Du kannst helfen, indem du deine **Ideen**, **Probleme** und **Feedback** teilst!

Der beste Ort für deine **Ideen** und **Probleme** ist der [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Der beste Ort für **schnelles**, unstrukturiertes Feedback ist die [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Du kannst diese Orte auch direkt aus der App auf der '**ⓘ Info**'-Registerkarte erreichen.

**Danke**, dass du hilfst, Mac Mouse Fix besser zu machen! 😎:)