Mac Mouse Fix **2.2.4** jest teraz notaryzowany! Zawiera również drobne poprawki błędów i inne ulepszenia.

### **Notaryzacja**

Mac Mouse Fix 2.2.4 jest teraz 'notaryzowany' przez Apple. Oznacza to koniec komunikatów o tym, że Mac Mouse Fix jest potencjalnie 'Złośliwym Oprogramowaniem' przy pierwszym otwarciu aplikacji.

#### Tło

Notaryzacja aplikacji kosztuje 100$ rocznie. Zawsze byłem temu przeciwny, ponieważ wydawało się to nieprzyjazne wobec darmowego i otwartego oprogramowania takiego jak Mac Mouse Fix, a także wydawało się niebezpiecznym krokiem w kierunku kontrolowania i zamykania systemu Mac przez Apple, tak jak robią to z iPhone'ami czy iPadami. Jednak brak notaryzacji prowadził do różnych problemów, w tym [trudności z otwarciem aplikacji](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114), a nawet [kilku sytuacji](https://github.com/noah-nuebling/mac-mouse-fix/issues/95), gdzie nikt nie mógł korzystać z aplikacji, dopóki nie wydałem nowej wersji.

Dla Mac Mouse Fix 3 uznałem, że w końcu warto zapłacić 100$ rocznie za notaryzację aplikacji, ponieważ Mac Mouse Fix 3 jest monetyzowany. ([Dowiedz się więcej](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Teraz Mac Mouse Fix 2 również otrzymuje notaryzację, co powinno zapewnić łatwiejsze i stabilniejsze doświadczenie użytkownika.

### **Poprawki błędów**

- Naprawiono problem, gdzie kursor znikał i pojawiał się w innym miejscu podczas używania akcji 'Kliknij i Przeciągnij' w trakcie nagrywania ekranu lub podczas korzystania z oprogramowania [DisplayLink](https://www.synaptics.com/products/displaylink-graphics).
- Naprawiono problem z włączaniem Mac Mouse Fix w macOS 10.14 Mojave i prawdopodobnie również w starszych wersjach macOS.
- Ulepszono zarządzanie pamięcią, potencjalnie naprawiając awarię aplikacji 'Mac Mouse Fix Helper', która występowała podczas odłączania myszy od komputera. Zobacz Dyskusję [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Inne Ulepszenia**

- Okno, które aplikacja wyświetla, aby poinformować o dostępności nowej wersji Mac Mouse Fix, teraz obsługuje JavaScript. Pozwala to na ładniejsze i łatwiejsze do przeczytania notatki o aktualizacji. Na przykład, notatki o aktualizacji mogą teraz wyświetlać [Alerty Markdown](https://github.com/orgs/community/discussions/16925) i więcej.
- Usunięto link do strony https://macmousefix.com/about/ z ekranu "Przyznaj dostęp do Dostępności dla Mac Mouse Fix Helper". Jest to spowodowane tym, że strona About już nie istnieje i została tymczasowo zastąpiona przez [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix).
- To wydanie zawiera teraz pliki dSYM, które mogą być używane przez każdego do dekodowania raportów o awariach Mac Mouse Fix 2.2.4.
- Kilka porządków i ulepszeń pod maską.

---

Sprawdź również poprzednie wydanie [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).