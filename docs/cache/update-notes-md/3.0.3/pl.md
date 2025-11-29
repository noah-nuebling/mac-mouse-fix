Mac Mouse Fix **3.0.3** jest gotowy na macOS 15 Sequoia. Naprawia również niektóre problemy ze stabilnością i wprowadza kilka drobnych ulepszeń.

### Wsparcie dla macOS 15 Sequoia

Aplikacja działa teraz prawidłowo pod macOS 15 Sequoia!

- Większość animacji interfejsu nie działała pod macOS 15 Sequoia. Teraz wszystko znów działa prawidłowo!
- Kod źródłowy można teraz kompilować pod macOS 15 Sequoia. Wcześniej występowały problemy z kompilatorem Swift uniemożliwiające zbudowanie aplikacji.

### Rozwiązywanie problemów z awariami podczas przewijania

Od wersji Mac Mouse Fix 3.0.2 pojawiło się [wiele zgłoszeń](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) dotyczących okresowego wyłączania i ponownego włączania się Mac Mouse Fix podczas przewijania. Było to spowodowane awariami aplikacji działającej w tle 'Mac Mouse Fix Helper'. Ta aktualizacja ma na celu naprawienie tych awarii, wprowadzając następujące zmiany:

- Mechanizm przewijania będzie próbował się odzyskać i kontynuować działanie zamiast ulegać awarii, gdy napotka przypadek brzegowy, który prawdopodobnie prowadził do tych awarii.
- Zmieniłem sposób, w jaki aplikacja ogólnie radzi sobie z nieoczekiwanymi stanami: Zamiast zawsze natychmiast ulegać awarii, aplikacja będzie teraz w wielu przypadkach próbowała odzyskać się z nieoczekiwanych stanów.
    
    - Ta zmiana przyczynia się do naprawy awarii podczas przewijania opisanych powyżej. Może również zapobiec innym awariom.
  
Uwaga: Nigdy nie udało mi się odtworzyć tych awarii na moim komputerze i nadal nie jestem pewien, co je powodowało, ale na podstawie otrzymanych zgłoszeń ta aktualizacja powinna zapobiec wszelkim awariom. Jeśli nadal doświadczasz awarii podczas przewijania lub *doświadczałeś* awarii w wersji 3.0.2, byłoby bardzo cenne, gdybyś podzielił się swoim doświadczeniem i danymi diagnostycznymi w zgłoszeniu GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Pomogłoby mi to zrozumieć problem i ulepszyć Mac Mouse Fix. Dziękuję!

### Rozwiązywanie problemów z zacinaniem się przewijania

W wersji 3.0.2 wprowadziłem zmiany w sposobie, w jaki Mac Mouse Fix wysyła zdarzenia przewijania do systemu, próbując zmniejszyć zacinanie się przewijania prawdopodobnie spowodowane problemami z API VSync firmy Apple.

Jednak po bardziej obszernych testach i opiniach wydaje się, że nowy mechanizm w wersji 3.0.2 sprawia, że przewijanie jest płynniejsze w niektórych scenariuszach, ale bardziej zacinające się w innych. Szczególnie w Firefoksie wydawało się to być zauważalnie gorsze. \
Ogólnie rzecz biorąc, nie było jasne, czy nowy mechanizm rzeczywiście poprawił zacinanie się przewijania we wszystkich przypadkach. Ponadto mógł przyczynić się do awarii podczas przewijania opisanych powyżej.

Dlatego wyłączyłem nowy mechanizm i przywróciłem mechanizm VSync dla zdarzeń przewijania do stanu z Mac Mouse Fix 3.0.0 i 3.0.1.

Zobacz zgłoszenie GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875), aby uzyskać więcej informacji.

### Zwrot pieniędzy

Przepraszam za kłopoty związane ze zmianami w przewijaniu w wersjach 3.0.1 i 3.0.2. Znacznie nie doceniłem problemów, które się z tym wiązały, i zbyt wolno reagowałem na te problemy. Zrobię wszystko, co w mojej mocy, aby wyciągnąć wnioski z tego doświadczenia i być bardziej ostrożnym z takimi zmianami w przyszłości. Chciałbym również zaoferować zwrot pieniędzy każdemu, kogo to dotyczy. Po prostu kliknij [tutaj](https://redirect.macmousefix.com/?target=mmf-apply-for-refund), jeśli jesteś zainteresowany.

### Mądrzejszy mechanizm aktualizacji

Te zmiany zostały przeniesione z Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) i [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Sprawdź ich notatki o wydaniu, aby dowiedzieć się więcej o szczegółach. Oto podsumowanie:

- Pojawił się nowy, mądrzejszy mechanizm, który decyduje, którą aktualizację pokazać użytkownikowi.
- Przełączono się z używania frameworka aktualizacji Sparkle 1.26.0 na najnowszy Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- Okno, które aplikacja wyświetla, aby poinformować cię, że dostępna jest nowa wersja Mac Mouse Fix, obsługuje teraz JavaScript, co pozwala na ładniejsze formatowanie notatek o aktualizacji.

### Inne ulepszenia i poprawki błędów

- Naprawiono problem, w którym cena aplikacji i powiązane informacje były w niektórych przypadkach wyświetlane nieprawidłowo na karcie 'O programie'.
- Naprawiono problem, w którym mechanizm synchronizacji płynnego przewijania z częstotliwością odświeżania ekranu nie działał prawidłowo podczas korzystania z wielu wyświetlaczy.
- Wiele drobnych ulepszeń i porządków pod maską.

---

Sprawdź również poprzednie wydanie [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).