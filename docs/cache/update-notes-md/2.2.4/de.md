Mac Mouse Fix **2.2.4** ist jetzt notarisiert! Es enthält auch einige kleine Fehlerbehebungen und weitere Verbesserungen.

### **Notarisierung**

Mac Mouse Fix 2.2.4 ist jetzt von Apple 'notarisiert'. Das bedeutet keine weiteren Meldungen mehr darüber, dass Mac Mouse Fix möglicherweise 'Schadsoftware' sei, wenn du die App zum ersten Mal öffnest.

#### Hintergrund

Die Notarisierung einer App kostet 100$ pro Jahr. Ich war immer dagegen, da es sich feindlich gegenüber freier und Open-Source-Software wie Mac Mouse Fix anfühlte und es auch wie ein gefährlicher Schritt in Richtung Apple-Kontrolle und Absperrung des Mac wie bei iPhones oder iPads erschien. Aber das Fehlen der Notarisierung führte zu verschiedenen Problemen, einschließlich [Schwierigkeiten beim Öffnen der App](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) und sogar [mehreren Situationen](https://github.com/noah-nuebling/mac-mouse-fix/issues/95), in denen niemand die App mehr nutzen konnte, bis ich eine neue Version veröffentlichte.

Für Mac Mouse Fix 3 hielt ich es endlich für angemessen, die 100$ pro Jahr für die Notarisierung der App zu zahlen, da Mac Mouse Fix 3 monetarisiert ist. ([Mehr erfahren](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Jetzt erhält auch Mac Mouse Fix 2 die Notarisierung, was zu einer einfacheren und stabileren Benutzererfahrung führen sollte.

### **Fehlerbehebungen**

- Ein Problem wurde behoben, bei dem der Cursor verschwand und an einer anderen Stelle wieder auftauchte, wenn eine 'Klicken und Ziehen'-Aktion während einer Bildschirmaufnahme oder bei Verwendung der [DisplayLink](https://www.synaptics.com/products/displaylink-graphics)-Software ausgeführt wurde.
- Ein Problem beim Aktivieren von Mac Mouse Fix unter macOS 10.14 Mojave und möglicherweise auch älteren macOS-Versionen wurde behoben.
- Verbessertes Speichermanagement, das möglicherweise einen Absturz der 'Mac Mouse Fix Helper'-App behebt, der beim Trennen einer Maus vom Computer auftrat. Siehe Diskussion [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Weitere Verbesserungen**

- Das Fenster, das die App anzeigt, um dich über eine neue Version von Mac Mouse Fix zu informieren, unterstützt jetzt JavaScript. Dies ermöglicht schönere und besser lesbare Update-Hinweise. Zum Beispiel können die Update-Hinweise jetzt [Markdown Alerts](https://github.com/orgs/community/discussions/16925) und mehr anzeigen.
- Ein Link zur https://macmousefix.com/about/ Seite wurde vom "Gewähre Zugriffsrechte für Mac Mouse Fix Helper"-Bildschirm entfernt. Dies liegt daran, dass die About-Seite nicht mehr existiert und vorerst durch das [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix) ersetzt wurde.
- Diese Version enthält jetzt dSYM-Dateien, die von jedem zum Dekodieren von Absturzberichten von Mac Mouse Fix 2.2.4 verwendet werden können.
- Einige Aufräumarbeiten und Verbesserungen unter der Haube.

---

Sieh dir auch die vorherige Version [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3) an.