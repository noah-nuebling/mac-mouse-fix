**ℹ️ Informacja dla użytkowników Mac Mouse Fix 2**

Wraz z wprowadzeniem Mac Mouse Fix 3, model cenowy aplikacji uległ zmianie:

- **Mac Mouse Fix 2**\
Pozostaje w 100% darmowy i planuję dalej go wspierać.\
**Pomiń tę aktualizację**, aby nadal korzystać z Mac Mouse Fix 2. Pobierz najnowszą wersję Mac Mouse Fix 2 [tutaj](https://redirect.macmousefix.com/?target=mmf2-latest).
- **Mac Mouse Fix 3**\
Darmowy przez 30 dni, kosztuje kilka dolarów, aby posiadać.\
**Zaktualizuj teraz**, aby otrzymać Mac Mouse Fix 3!

Więcej informacji o cenach i funkcjach Mac Mouse Fix 3 znajdziesz na [nowej stronie](https://macmousefix.com/).

Dziękuję za korzystanie z Mac Mouse Fix! :)

---

**ℹ️ Informacja dla nabywców Mac Mouse Fix 3**

Jeśli przypadkowo zaktualizowałeś do Mac Mouse Fix 3 nie wiedząc, że nie jest już darmowy, chciałbym zaoferować Ci [zwrot pieniędzy](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

Najnowsza wersja Mac Mouse Fix 2 pozostaje **całkowicie darmowa** i możesz ją pobrać [tutaj](https://redirect.macmousefix.com/?target=mmf2-latest).

Przepraszam za kłopot i mam nadzieję, że to rozwiązanie jest dla wszystkich odpowiednie!

---

Mac Mouse Fix **3.0.3** jest gotowy na macOS 15 Sequoia. Naprawia również problemy ze stabilnością i wprowadza kilka drobnych ulepszeń.

### Wsparcie dla macOS 15 Sequoia

Aplikacja działa teraz poprawnie pod macOS 15 Sequoia!

- Większość animacji UI była uszkodzona w macOS 15 Sequoia. Teraz wszystko działa znowu prawidłowo!
- Kod źródłowy można teraz skompilować pod macOS 15 Sequoia. Wcześniej występowały problemy z kompilatorem Swift uniemożliwiające kompilację aplikacji.

### Rozwiązanie problemów z przewijaniem

Od wersji Mac Mouse Fix 3.0.2 pojawiło się [wiele zgłoszeń](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) o tym, że Mac Mouse Fix okresowo wyłącza się i włącza podczas przewijania. Było to spowodowane awariami aplikacji 'Mac Mouse Fix Helper' działającej w tle. Ta aktualizacja próbuje naprawić te awarie poprzez następujące zmiany:

- Mechanizm przewijania będzie próbował się odzyskać i kontynuować działanie zamiast się zawieszać, gdy napotka przypadek brzegowy, który prawdopodobnie prowadził do tych awarii.
- Zmieniłem sposób obsługi nieoczekiwanych stanów w aplikacji: Zamiast zawsze natychmiast się zawieszać, aplikacja będzie teraz w wielu przypadkach próbować odzyskać się z nieoczekiwanych stanów.

    - Ta zmiana przyczynia się do naprawy awarii przewijania opisanych powyżej. Może również zapobiec innym awariom.

Uwaga: Nigdy nie udało mi się odtworzyć tych awarii na moim komputerze i nadal nie jestem pewien, co je powodowało, ale na podstawie otrzymanych zgłoszeń ta aktualizacja powinna zapobiec wszelkim awariom. Jeśli nadal doświadczasz awarii podczas przewijania lub doświadczyłeś awarii w wersji 3.0.2, byłoby cenne, gdybyś podzielił się swoim doświadczeniem i danymi diagnostycznymi w GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Pomoże mi to zrozumieć problem i ulepszyć Mac Mouse Fix. Dziękuję!

### Rozwiązanie problemów z zacinaniem się przewijania

W wersji 3.0.2 wprowadziłem zmiany w sposobie wysyłania zdarzeń przewijania do systemu, próbując zmniejszyć zacinanie się przewijania prawdopodobnie spowodowane problemami z API VSync Apple.

Jednak po bardziej szczegółowych testach i otrzymaniu opinii okazało się, że nowy mechanizm w 3.0.2 sprawia, że przewijanie jest płynniejsze w niektórych scenariuszach, ale bardziej się zacina w innych. Szczególnie w Firefox wydawało się zauważalnie gorsze.\
Ogólnie nie było jasne, czy nowy mechanizm faktycznie poprawił płynność przewijania. Mógł również przyczynić się do awarii przewijania opisanych powyżej.

Dlatego wyłączyłem nowy mechanizm i przywróciłem mechanizm VSync dla zdarzeń przewijania do stanu z Mac Mouse Fix 3.0.0 i 3.0.1.

Zobacz GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) aby uzyskać więcej informacji.

### Zwrot pieniędzy

Przepraszam za problemy związane ze zmianami w przewijaniu w wersjach 3.0.1 i 3.0.2. Znacznie nie doceniłem problemów, które się z tym wiązały, i zbyt wolno reagowałem na te problemy. Postaram się wyciągnąć wnioski z tego doświadczenia i być bardziej ostrożnym przy takich zmianach w przyszłości. Chciałbym również zaoferować zwrot pieniędzy wszystkim poszkodowanym. Wystarczy kliknąć [tutaj](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) jeśli jesteś zainteresowany.

### Inteligentniejszy mechanizm aktualizacji

Te zmiany zostały przeniesione z Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) i [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Sprawdź ich informacje o wydaniu, aby dowiedzieć się więcej o szczegółach. Oto podsumowanie:

- Istnieje nowy, inteligentniejszy mechanizm decydujący o tym, którą aktualizację pokazać użytkownikowi.
- Przełączono się z używania frameworka aktualizacji Sparkle 1.26.0 na najnowszy Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- Okno, które aplikacja wyświetla, aby poinformować o dostępności nowej wersji Mac Mouse Fix, teraz obsługuje JavaScript, co pozwala na ładniejsze formatowanie notatek o aktualizacji.

### Inne ulepszenia i poprawki błędów

- Naprawiono problem, gdzie cena aplikacji i powiązane informacje były nieprawidłowo wyświetlane w zakładce 'O programie' w niektórych przypadkach.
- Naprawiono problem, gdzie mechanizm synchronizacji płynnego przewijania z częstotliwością odświeżania ekranu nie działał prawidłowo podczas korzystania z wielu wyświetlaczy.
- Wiele drobnych porządków i ulepszeń pod maską.

---

Sprawdź również poprzednie wydanie [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).