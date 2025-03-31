Sprawdź też **świetne zmiany** wprowadzone w [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

**3.0.0 Beta 6** wprowadza głębokie optymalizacje i ulepszenia, przebudowę ustawień przewijania, tłumaczenia na język chiński i więcej!

Oto wszystkie nowości:

## 1. Głębokie Optymalizacje

W tej wersji Beta włożyłem dużo pracy w wydobycie maksymalnej wydajności z Mac Mouse Fix. Teraz z dumą mogę ogłosić, że kliknięcie przycisku myszy w Beta 6 jest **2x** szybsze w porównaniu do poprzedniej bety! A przewijanie jest nawet **4x** szybsze!

W Beta 6, MMF będzie też inteligentnie wyłączać niektóre swoje części, aby maksymalnie oszczędzać procesor i baterię.

Na przykład, gdy używasz myszy z 3 przyciskami, ale masz skonfigurowane akcje tylko dla przycisków, których nie ma w twojej myszy (jak przyciski 4 i 5), Mac Mouse Fix całkowicie przestanie nasłuchiwać sygnałów z przycisków myszy. Oznacza to 0% użycia procesora podczas klikania! Albo gdy ustawienia przewijania w MMF są zgodne z systemowymi, Mac Mouse Fix przestanie całkowicie nasłuchiwać sygnałów z kółka myszy. Oznacza to 0% użycia procesora podczas przewijania! Ale jeśli ustawisz funkcję Command (⌘)-Scroll do przybliżania, Mac Mouse Fix zacznie nasłuchiwać sygnałów z kółka myszy - ale tylko gdy trzymasz klawisz Command (⌘). I tak dalej.
Jest więc naprawdę inteligentny i będzie używać procesora tylko wtedy, gdy musi!

Oznacza to, że MMF jest teraz nie tylko najpotężniejszym, najprostszym w użyciu i najbardziej dopracowanym sterownikiem myszy dla Maca, ale także jednym z najbardziej, jeśli nie najbardziej, zoptymalizowanym i wydajnym!

## 2. Zmniejszony Rozmiar Aplikacji

Przy 16 MB, Beta 6 jest około 2x mniejsza niż Beta 5!

Jest to efekt uboczny porzucenia wsparcia dla starszych wersji macOS.

## 3. Porzucenie Wsparcia dla Starszych Wersji macOS

Starałem się, aby MMF 3 działał poprawnie na wersjach macOS przed macOS 11 Big Sur. Ale ilość pracy potrzebnej do osiągnięcia dopracowanego efektu okazała się przytłaczająca, więc musiałem z tego zrezygnować.

Od teraz, najwcześniejszą oficjalnie wspieraną wersją będzie macOS 11 Big Sur.

Aplikacja nadal będzie się otwierać na starszych wersjach, ale będą występować problemy wizualne i być może inne. Aplikacja nie będzie się już uruchamiać na wersjach macOS przed 10.14.4. To właśnie pozwala nam zmniejszyć rozmiar aplikacji 2-krotnie, ponieważ 10.14.4 jest najwcześniejszą wersją macOS zawierającą nowoczesne biblioteki Swift (Zobacz "Swift ABI Stability"), co oznacza, że te biblioteki Swift nie muszą już być zawarte w aplikacji.

## 4. Ulepszenia Przewijania

Beta 6 zawiera wiele ulepszeń w konfiguracji i interfejsie użytkownika nowych systemów przewijania wprowadzonych w MMF 3.

### Interfejs Użytkownika

- Znacznie uproszczono i skrócono tekst interfejsu w zakładce Przewijanie. Większość wzmianek o słowie "Przewijanie" została usunięta, ponieważ wynika to z kontekstu.
- Przebudowano ustawienia płynności przewijania, aby były jaśniejsze i umożliwiały dodatkowe opcje. Teraz możesz wybrać między "Płynnością" "Wyłączoną", "Regularną" lub "Wysoką", zastępując stary przełącznik "z Inercją". Myślę, że jest to znacznie jaśniejsze i zrobiło miejsce w interfejsie na nową opcję "Symulacja Trackpada".
- Wyłączenie nowej opcji "Symulacja Trackpada" wyłącza efekt gumowej taśmy podczas przewijania, zapobiega też przewijaniu między stronami w Safari i innych aplikacjach, i więcej. Wiele osób było tym zirytowanych, szczególnie ci z kółkami przewijania bez blokady, jak w niektórych myszkach Logitech, np. MX Master, ale inni to lubią, więc zdecydowałem się zrobić z tego opcję. Mam nadzieję, że prezentacja tej funkcji jest jasna. Jeśli masz jakieś sugestie, daj mi znać.
- Zmieniono opcję "Naturalny Kierunek Przewijania" na "Odwróć Kierunek Przewijania". Oznacza to, że ustawienie teraz odwraca systemowy kierunek przewijania i nie jest już niezależne od systemowego kierunku przewijania. Chociaż jest to prawdopodobnie nieco gorsze doświadczenie użytkownika, ten nowy sposób działania pozwala nam zaimplementować pewne optymalizacje i sprawia, że jest bardziej przejrzyste dla użytkownika, jak całkowicie wyłączyć Mac Mouse Fix dla przewijania.
- Ulepszono sposób, w jaki ustawienia przewijania współdziałają z modyfikowanym przewijaniem w wielu różnych przypadkach brzegowych. Np. opcja "Precyzja" nie będzie już stosowana do akcji "Kliknij i Przewiń" dla "Pulpit i Launchpad", ponieważ jest tu przeszkodą zamiast pomocą.
- Poprawiono prędkość przewijania przy używaniu "Kliknij i Przewiń" dla "Pulpit i Launchpad" lub "Przybliż lub Oddal" i innych funkcji.
- Usunięto niedziałający link do systemowych ustawień prędkości przewijania w zakładce przewijania, który był obecny w wersjach macOS przed macOS 13.0 Ventura. Nie mogłem znaleźć sposobu na sprawienie, by link działał, a nie jest to szczególnie ważne.

### Odczucie Przewijania

- Poprawiono krzywą animacji dla "Regularnej Płynności" (wcześniej dostępnej przez wyłączenie "z Inercją"). To sprawia, że wszystko jest bardziej płynne i responsywne.
- Poprawiono odczucie wszystkich ustawień prędkości przewijania. Prędkości "Średnia" i "Szybka" są szybsze. Jest większa różnica między prędkościami "Niska", "Średnia" i "Wysoka". Przyspieszenie podczas szybszego poruszania kółkiem myszy wydaje się bardziej naturalne i wygodne przy używaniu opcji "Precyzja".
- Sposób, w jaki prędkość przewijania wzrasta podczas ciągłego przewijania w jednym kierunku, będzie bardziej naturalny i stopniowy. Używam nowych krzywych matematycznych do modelowania przyspieszenia. Przyspieszenie będzie też trudniejsze do przypadkowego uruchomienia.
- Brak przyspieszania prędkości przewijania podczas ciągłego przewijania w jednym kierunku przy używaniu prędkości przewijania "macOS".
- Ograniczono maksymalny czas animacji przewijania. Jeśli animacja przewijania naturalnie trwałaby dłużej, zostanie przyspieszona, aby pozostać poniżej maksymalnego czasu. Dzięki temu przewijanie do krawędzi strony kółkiem bez blokady nie spowoduje tak długiego przesunięcia zawartości strony poza ekran. Nie powinno to wpływać na normalne przewijanie kółkiem z blokadą.
- Poprawiono niektóre interakcje związane z efektem gumowej taśmy podczas przewijania do krawędzi strony w Safari i innych aplikacjach.
- Naprawiono problem, gdzie "Kliknij i Przewiń" i inne funkcje związane z przewijaniem nie działały poprawnie po aktualizacji z bardzo starej wersji panelu preferencji Mac Mouse Fix.
- Naprawiono problem, gdzie pojedyncze piksele przewijania były wysyłane z opóźnieniem przy używaniu prędkości przewijania "macOS" razem z płynnym przewijaniem.
- Naprawiono błąd, gdzie przewijanie nadal było bardzo szybkie po zwolnieniu modyfikatora Szybkiego Przewijania. Inne ulepszenia dotyczące tego, jak prędkość przewijania jest przenoszona z poprzednich przesunięć.
- Poprawiono sposób, w jaki prędkość przewijania zwiększa się przy większych rozmiarach wyświetlacza.

## 5. Notaryzacja

Począwszy od 3.0.0 Beta 6, Mac Mouse Fix będzie "Notaryzowany". Oznacza to brak więcej komunikatów o tym, że Mac Mouse Fix jest potencjalnie "Złośliwym Oprogramowaniem" przy pierwszym otwarciu aplikacji.

Notaryzacja aplikacji kosztuje 100$ rocznie. Zawsze byłem temu przeciwny, ponieważ wydawało się to wrogie wobec darmowego i otwartego oprogramowania jak Mac Mouse Fix, a także wydawało się niebezpiecznym krokiem w kierunku kontrolowania i zamykania Maca przez Apple, jak robią to z iOS. Ale brak Notaryzacji prowadził do dość poważnych problemów, w tym [kilku sytuacji](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114), gdzie nikt nie mógł używać aplikacji, dopóki nie wydałem nowej wersji. Ponieważ Mac Mouse Fix będzie teraz monetyzowany, uznałem, że w końcu właściwe jest Notaryzowanie aplikacji dla łatwiejszego i stabilniejszego doświadczenia użytkownika.

## 6. Tłumaczenia na Chiński

Mac Mouse Fix jest teraz dostępny po chińsku!
Dokładniej, jest dostępny w:

- Chiński, Tradycyjny
- Chiński, Uproszczony
- Chiński (Hong Kong)

Ogromne podziękowania dla @groverlynn za dostarczenie wszystkich tych tłumaczeń, a także za ich aktualizowanie podczas bet i komunikację ze mną. Zobacz jego pull request tutaj: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Wszystko Inne

Oprócz zmian wymienionych powyżej, Beta 6 zawiera również wiele mniejszych ulepszeń.

- Usunięto kilka opcji z Akcji "Kliknij", "Kliknij i Przytrzymaj" oraz "Kliknij i Przewiń", ponieważ uznałem je za redundantne, gdyż tę samą funkcjonalność można osiągnąć inaczej, a to upraszcza menu. Przywrócę te opcje, jeśli ludzie będą narzekać. Więc jeśli brakuje ci tych opcji - proszę narzekaj.
- Kierunek Kliknij i Przeciągnij będzie teraz odpowiadał kierunkowi przeciągania trackpadem nawet gdy "Naturalne przewijanie" jest wyłączone w Ustawieniach Systemowych > Trackpad. Wcześniej Kliknij i Przeciągnij zawsze zachowywał się jak przeciąganie na trackpadzie z włączonym "Naturalnym przewijaniem".
- Naprawiono problem, gdzie kursory znikały i pojawiały się gdzie indziej podczas używania Akcji "Kliknij i Przeciągnij" podczas nagrywania ekranu lub przy używaniu oprogramowania DisplayLink.
- Naprawiono wycentrowanie "+" w Polu "+" w zakładce Przyciski
- Kilka wizualnych ulepszeń w zakładce Przyciski. Paleta kolorów Pola "+" i Tabeli Akcji została przepracowana, aby wyglądała poprawnie przy używaniu opcji macOS "Zezwalaj na zabarwianie okien tapetą". Obramowania Tabeli Akcji mają teraz przezroczysty kolor, który wygląda bardziej dynamicznie i dostosowuje się do otoczenia.
- Sprawiono, że gdy dodajesz dużo akcji do tabeli akcji i okno Mac Mouse Fix się powiększa, urośnie dokładnie do rozmiaru ekranu (lub do rozmiaru ekranu minus dok, jeśli nie masz włączonego ukrywania doku) i zatrzyma się. Gdy dodasz jeszcze więcej akcji, tabela akcji zacznie się przewijać.
- Ta Beta wspiera teraz nową opcję płatności, gdzie możesz kupić licencję w dolarach amerykańskich, jak reklamowano. Wcześniej można było kupić licencję tylko w euro. Stare licencje w euro będą oczywiście nadal wspierane.
- Naprawiono problem, gdzie przewijanie z rozpędem czasami nie było uruchamiane przy używaniu funkcji "Przewiń i Nawiguj".
- Gdy okno Mac Mouse Fix zmienia rozmiar podczas przełączania zakładek, teraz zmieni swoją pozycję tak, aby nie nakładało się na Dok
- Naprawiono migotanie niektórych elementów interfejsu przy przełączaniu z zakładki Przyciski na inną zakładkę
- Poprawiono wygląd animacji, którą Pole "+" odtwarza po nagraniu sygnału wejściowego. Szczególnie na wersjach macOS przed Ventura, gdzie cień Pola "+" wyglądał błędnie podczas animacji.
- Wyłączono powiadomienia wymieniające kilka przycisków, które zostały przechwycone/nie są już przechwytywane przez Mac Mouse Fix, które pojawiały się przy pierwszym uruchomieniu aplikacji lub przy ładowaniu presetu. Uznałem, że te komunikaty były rozpraszające i nieco przytłaczające oraz niezbyt pomocne w tych kontekstach.
- Przebudowano Ekran Przyznawania Dostępu do Ułatwień Dostępu. Teraz będzie pokazywać informacje o tym, dlaczego Mac Mouse Fix potrzebuje Dostępu do Ułatwień Dostępu bezpośrednio zamiast linkować do strony internetowej i jest nieco jaśniejszy oraz ma bardziej przyjemny wizualnie układ.
- Zaktualizowano link do Podziękowań w zakładce O programie.
- Poprawiono komunikaty o błędach, gdy Mac Mouse Fix nie może być włączony, ponieważ inna wersja jest obecna w systemie. Komunikat będzie teraz wyświetlany w pływającym oknie alertu, które zawsze pozostaje na wierzchu innych okien do momentu zamknięcia, zamiast Powiadomienia Toast, które znika po kliknięciu gdziekolwiek. Powinno to ułatwić podążanie za sugerowanymi krokami rozwiązania.
- Naprawiono niektóre problemy z renderowaniem markdown na wersjach macOS przed Ventura. MMF będzie teraz używać własnego rozwiązania do renderowania markdown dla wszystkich wersji macOS, włącznie z Ventura. Wcześniej używaliśmy API systemowego wprowadzonego w Ventura, ale to prowadziło do niespójności. Markdown jest używany do dodawania linków i wyróżnień w tekście w całym interfejsie.
- Dopracowano interakcje związane z włączaniem dostępu do ułatwień dostępu.
- Naprawiono problem, gdzie okno aplikacji czasami otwierało się bez pokazywania zawartości, dopóki nie przełączyło się na jedną z zakładek.
- Naprawiono problem z Polem "+", gdzie czasami nie można było dodać nowej akcji, mimo że pokazywał się efekt najechania wskazujący, że można wprowadzić akcję.
- Naprawiono zakleszczenie i kilka innych małych problemów, które czasami występowały przy poruszaniu wskaźnikiem myszy wewnątrz Pola "+".
- Naprawiono problem, gdzie wyskakujące okienko pojawiające się w zakładce Przyciski, gdy twoja mysz wydaje się nie pasować do obecnych ustawień przycisków, czasami miało cały tekst pogrubiony.
- Zaktualizowano wszystkie wzmianki o starej licencji MIT na nową licencję MMF. Nowe pliki utworzone dla projektu będą teraz zawierać automatycznie generowany nagłówek wspominający licencję MMF.
- Sprawiono, że przełączanie na zakładkę Przyciski włącza MMF dla Przewijania. W przeciwnym razie nie można było nagrywać gestów Kliknij i Przewiń.
- Naprawiono niektóre problemy, gdzie nazwy przycisków nie wyświetlały się poprawnie w Tabeli Akcji w niektórych sytuacjach.
- Naprawiono błąd, gdzie sekcja próbna na ekranie O programie wyglądała błędnie przy otwieraniu aplikacji, a następnie przełączaniu na zakładkę próbną po wygaśnięciu okresu próbnego.
- Naprawiono błąd, gdzie link Aktywuj Licencję w sekcji próbnej zakładki O programie czasami nie reagował na kliknięcia.
- Naprawiono wyciek pamięci przy używaniu funkcji "Kliknij i Przeciągnij" dla "Spaces i Mission Control".
- Włączono Hardened runtime w głównej aplikacji Mac Mouse Fix, poprawiając bezpieczeństwo
- Dużo porządków w kodzie, restrukturyzacja projektu
- Naprawiono kilka innych awarii
- Naprawiono kilka wycieków pamięci
- Różne małe poprawki tekstu interfejsu
- Przebudowy kilku wewnętrznych systemów również poprawiły odporność i zachowanie w przypadkach brzegowych

## 8. Jak Możesz Pomóc

Możesz pomóc dzieląc się swoimi **pomysłami**, **problemami** i **opiniami**!

Najlepszym miejscem do dzielenia się **pomysłami** i **problemami** jest [Asystent Opinii](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Najlepszym miejscem do dawania **szybkich** nieustrukturyzowanych opinii jest [Dyskusja Opinii](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Możesz też dostać się do tych miejsc z poziomu aplikacji w zakładce "**ⓘ O programie**".

**Dziękuję** za pomoc w uczynieniu Mac Mouse Fix najlepszym, jakim może być! 🙌:)