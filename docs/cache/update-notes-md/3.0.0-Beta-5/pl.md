Sprawdź też **świetne zmiany** wprowadzone w [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

**3.0.0 Beta 5** przywraca **kompatybilność** z niektórymi **myszkami** w macOS 13 Ventura i **naprawia przewijanie** w wielu aplikacjach.
Zawiera również kilka innych drobnych poprawek i ulepszeń jakości życia.

Oto **wszystkie nowości**:

### Mysz

- Naprawiono przewijanie w Terminalu i innych aplikacjach! Zobacz problem na GitHub [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Naprawiono niekompatybilność z niektórymi myszkami w macOS 13 Ventura poprzez odejście od używania zawodnych API Apple na rzecz niskopoziomowych rozwiązań. Mam nadzieję, że nie wprowadzi to nowych problemów - daj znać, jeśli tak się stanie! Szczególne podziękowania dla Marii i użytkownika GitHub [samiulhsnt](https://github.com/samiulhsnt) za pomoc w rozwiązaniu tego problemu! Zobacz problem na GitHub [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) po więcej informacji.
- Nie będzie już zużywać CPU podczas klikania Przycisku 1 lub 2 myszy. Nieznacznie zmniejszono zużycie CPU podczas klikania innych przycisków.
    - To jest "Wersja Debug", więc zużycie CPU może być około 10 razy wyższe podczas klikania przycisków w tej becie w porównaniu z wersją finalną
- Symulacja przewijania trackpadem używana w funkcjach "Płynne przewijanie" i "Przewijanie i nawigacja" Mac Mouse Fix jest teraz jeszcze dokładniejsza. Może to prowadzić do lepszego zachowania w niektórych sytuacjach.

### Interfejs

- Automatyczne naprawianie problemów z przyznawaniem Dostępu do Ułatwień Dostępu po aktualizacji ze starszej wersji Mac Mouse Fix. Przyjmuje zmiany opisane w [notatkach do wydania 2.2.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Dodano przycisk "Anuluj" do ekranu "Przyznaj Dostęp do Ułatwień Dostępu"
- Naprawiono problem, gdzie konfiguracja Mac Mouse Fix nie działała poprawnie po zainstalowaniu nowej wersji Mac Mouse Fix, ponieważ nowa wersja łączyła się ze starą wersją "Mac Mouse Fix Helper". Teraz Mac Mouse Fix nie będzie już łączył się ze starym "Mac Mouse Fix Helper" i automatycznie wyłączy starą wersję, gdy będzie to konieczne.
- Przekazywanie użytkownikowi instrukcji jak naprawić problem, gdy Mac Mouse Fix nie może być właściwie włączony z powodu obecności innej wersji Mac Mouse Fix w systemie. Ten problem występuje tylko w macOS Ventura.
- Dopracowano zachowanie i animacje na ekranie "Przyznaj Dostęp do Ułatwień Dostępu"
- Mac Mouse Fix będzie przenoszony na pierwszy plan, gdy zostanie włączony. Poprawia to interakcje z interfejsem w niektórych sytuacjach, jak na przykład włączanie Mac Mouse Fix po tym, jak został wyłączony w Ustawieniach systemowych > Ogólne > Elementy logowania.
- Poprawiono teksty interfejsu na ekranie "Przyznaj Dostęp do Ułatwień Dostępu"
- Poprawiono teksty interfejsu wyświetlane podczas próby włączenia Mac Mouse Fix, gdy jest wyłączony w Ustawieniach systemowych
- Naprawiono niemiecki tekst interfejsu

### Pod maską

- Numer kompilacji "Mac Mouse Fix" i wbudowanego "Mac Mouse Fix Helper" są teraz zsynchronizowane. Jest to używane do zapobiegania przypadkowemu łączeniu się "Mac Mouse Fix" ze starymi wersjami "Mac Mouse Fix Helper".
- Naprawiono problem, gdzie niektóre dane dotyczące licencji i okresu próbnego czasami wyświetlały się niepoprawnie przy pierwszym uruchomieniu aplikacji poprzez usunięcie danych cache z początkowej konfiguracji
- Dużo porządków w strukturze projektu i kodzie źródłowym
- Ulepszone komunikaty debugowania

---

### Jak możesz pomóc

Możesz pomóc dzieląc się swoimi **pomysłami**, **problemami** i **opiniami**!

Najlepszym miejscem do dzielenia się **pomysłami** i **problemami** jest [Asystent Opinii](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Najlepszym miejscem do przekazywania **szybkich** nieustrukturyzowanych opinii jest [Dyskusja Opinii](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Możesz również uzyskać dostęp do tych miejsc z poziomu aplikacji w zakładce "**ⓘ O programie**".

**Dziękuję** za pomoc w ulepszaniu Mac Mouse Fix! 💙💛❤️