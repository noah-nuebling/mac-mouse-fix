Mac Mouse Fix **2.2.5** zawiera ulepszenia mechanizmu aktualizacji i jest gotowy na macOS 15 Sequoia!

### Nowy framework aktualizacji Sparkle

Mac Mouse Fix wykorzystuje framework aktualizacji [Sparkle](https://sparkle-project.org/) do zapewnienia świetnego doświadczenia podczas aktualizacji.

W wersji 2.2.5 Mac Mouse Fix przechodzi ze Sparkle 1.26.0 na najnowszy Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), zawierający poprawki bezpieczeństwa, ulepszenia lokalizacji i więcej.

### Inteligentniejszy mechanizm aktualizacji

Pojawił się nowy mechanizm decydujący o tym, którą aktualizację pokazać użytkownikowi. Zachowanie zmieniło się w następujący sposób:

1. Po pominięciu aktualizacji **głównej** (np. 2.2.5 -> 3.0.0), nadal będziesz otrzymywać powiadomienia o nowych aktualizacjach **pomniejszych** (np. 2.2.5 -> 2.2.6).
    - Pozwala to łatwo pozostać przy Mac Mouse Fix 2, jednocześnie otrzymując aktualizacje, jak omówiono w GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Zamiast pokazywać aktualizację do najnowszej wersji, Mac Mouse Fix będzie teraz pokazywać aktualizację do pierwszej wersji najnowszej wersji głównej.
    - Przykład: Jeśli używasz MMF 2.2.5, a MMF 3.4.5 jest najnowszą wersją, aplikacja pokaże teraz pierwszą wersję MMF 3 (3.0.0), zamiast najnowszej wersji (3.4.5). W ten sposób wszyscy użytkownicy MMF 2.2.5 zobaczą changelog MMF 3.0.0 przed przejściem na MMF 3.
    - Dyskusja:
        - Główną motywacją było to, że wcześniej w tym roku wielu użytkowników MMF 2 zaktualizowało się bezpośrednio z MMF 2 do MMF 3.0.1 lub 3.0.2. Ponieważ nigdy nie widzieli changeloga 3.0.0, przeoczyli informacje o zmianach w cenach między MMF 2 a MMF 3 (MMF 3 nie jest już w 100% darmowy). Więc kiedy MMF 3 nagle zażądał opłaty za dalsze korzystanie z aplikacji, niektórzy byli - co zrozumiałe - nieco zdezorientowani i zdenerwowani.
        - Wada: Jeśli chcesz po prostu zaktualizować do najnowszej wersji, w niektórych przypadkach będziesz musiał zaktualizować się dwukrotnie. Jest to nieco nieefektywne, ale nadal powinno zająć tylko kilka sekund. A ponieważ sprawia to, że zmiany między głównymi wersjami są znacznie bardziej przejrzyste, uważam, że to rozsądny kompromis.

### Wsparcie dla macOS 15 Sequoia

Mac Mouse Fix 2.2.5 będzie działać świetnie na nowym macOS 15 Sequoia - tak samo jak 2.2.4.

---

Sprawdź również poprzednią wersję [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Jeśli masz problemy z włączeniem Mac Mouse Fix po aktualizacji, zapoznaj się z ['Przewodnikiem włączania Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*