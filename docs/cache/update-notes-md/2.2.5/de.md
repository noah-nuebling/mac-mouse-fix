Mac Mouse Fix **2.2.5** bringt Verbesserungen am Update-Mechanismus und ist bereit für macOS 15 Sequoia!

### Neues Sparkle Update-Framework

Mac Mouse Fix verwendet das [Sparkle](https://sparkle-project.org/) Update-Framework, um ein großartiges Update-Erlebnis zu bieten.

Mit 2.2.5 wechselt Mac Mouse Fix von Sparkle 1.26.0 zur neuesten Version [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), die Sicherheitskorrekturen, Lokalisierungsverbesserungen und mehr enthält.

### Intelligenterer Update-Mechanismus

Es gibt einen neuen Mechanismus, der entscheidet, welches Update dem Nutzer angezeigt wird. Das Verhalten hat sich in folgenden Punkten geändert:

1. Nachdem du ein **Major**-Update übersprungen hast (wie 2.2.5 -> 3.0.0), wirst du trotzdem über neue **Minor**-Updates informiert (wie 2.2.5 -> 2.2.6).
    - Dies ermöglicht es dir, einfach bei Mac Mouse Fix 2 zu bleiben und trotzdem Updates zu erhalten, wie in GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962) diskutiert.
2. Anstatt das Update auf die neueste Version anzuzeigen, wird Mac Mouse Fix dir nun das Update auf die erste Version der neuesten Major-Version zeigen.
    - Beispiel: Wenn du MMF 2.2.5 verwendest und MMF 3.4.5 die neueste Version ist, wird die App dir jetzt die erste Version von MMF 3 (3.0.0) anzeigen, anstatt der neuesten Version (3.4.5). Auf diese Weise sehen alle MMF 2.2.5 Nutzer das MMF 3.0.0 Changelog, bevor sie zu MMF 3 wechseln.
    - Diskussion:
        - Der Hauptgrund dafür ist, dass Anfang dieses Jahres viele MMF 2 Nutzer direkt von MMF 2 auf MMF 3.0.1 oder 3.0.2 aktualisierten. Da sie nie das 3.0.0 Changelog sahen, verpassten sie Informationen über die Preisänderungen zwischen MMF 2 und MMF 3 (MMF 3 ist nicht mehr 100% kostenlos). Als MMF 3 dann plötzlich verlangte, dass sie für die weitere Nutzung der App bezahlen müssen, waren einige - verständlicherweise - etwas verwirrt und verärgert.
        - Nachteil: Wenn du einfach auf die neueste Version aktualisieren möchtest, musst du in manchen Fällen nun zweimal updaten. Das ist etwas ineffizient, sollte aber trotzdem nur wenige Sekunden dauern. Da dies die Änderungen zwischen Major-Versionen viel transparenter macht, halte ich es für einen sinnvollen Kompromiss.

### macOS 15 Sequoia Unterstützung

Mac Mouse Fix 2.2.5 wird auf dem neuen macOS 15 Sequoia großartig funktionieren - genau wie 2.2.4.

---

Sieh dir auch das vorherige Release [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) an.

*Wenn du nach dem Update Probleme beim Aktivieren von Mac Mouse Fix hast, schau dir bitte den ['Mac Mouse Fix aktivieren' Guide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) an.*