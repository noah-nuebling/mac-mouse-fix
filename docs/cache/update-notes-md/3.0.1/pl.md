Mac Mouse Fix **3.0.1** przynosi kilka poprawek błędów i ulepszeń, a także **nowy język**!

### Dodano język wietnamski!

Mac Mouse Fix jest teraz dostępny w języku 🇻🇳 wietnamskim. Wielkie podziękowania dla @nghlt [na GitHubie](https://GitHub.com/nghlt)!

### Poprawki błędów

- Mac Mouse Fix działa teraz poprawnie z **Szybkim przełączaniem użytkowników**!
  - Szybkie przełączanie użytkowników to logowanie się na drugie konto macOS bez wylogowywania się z pierwszego.
  - Przed tą aktualizacją przewijanie przestawało działać po szybkim przełączeniu użytkownika. Teraz wszystko powinno działać prawidłowo.
- Naprawiono drobny błąd, gdzie układ zakładki Przyciski był zbyt szeroki po pierwszym uruchomieniu Mac Mouse Fix.
- Usprawniono działanie pola '+' podczas dodawania kilku Akcji w krótkim odstępie czasu.
- Naprawiono rzadki błąd zgłoszony przez @V-Coba w Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Inne ulepszenia

- **Przewijanie jest bardziej responsywne** przy ustawieniu 'Płynność: Normalna'.
  - Prędkość animacji zwiększa się wraz z szybszym ruchem kółka myszy. Dzięki temu przewijanie jest bardziej responsywne przy szybkich ruchach, zachowując płynność przy wolnym przewijaniu.

- **Przyspieszenie przewijania** jest teraz bardziej stabilne i przewidywalne.
- Zaimplementowano mechanizm **zachowywania ustawień** podczas aktualizacji do nowej wersji Mac Mouse Fix.
  - Wcześniej Mac Mouse Fix resetował wszystkie ustawienia po aktualizacji do nowej wersji, jeśli struktura ustawień uległa zmianie. Teraz Mac Mouse Fix będzie próbował zaktualizować strukturę ustawień i zachować twoje preferencje.
  - Na razie działa to tylko przy aktualizacji z wersji 3.0.0 do 3.0.1. Jeśli aktualizujesz z wersji starszej niż 3.0.0 lub _downgradujesz_ z 3.0.1 _do_ poprzedniej wersji, twoje ustawienia nadal zostaną zresetowane.
- Układ zakładki Przyciski lepiej dostosowuje swoją szerokość do różnych języków.
- Ulepszenia w [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) i innych dokumentach.
- Ulepszono systemy lokalizacji. Pliki tłumaczeń są teraz automatycznie porządkowane i analizowane pod kątem potencjalnych problemów. Powstał nowy [Przewodnik po lokalizacji](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731), który zawiera automatycznie wykryte problemy wraz z innymi przydatnymi informacjami i instrukcjami dla osób chcących pomóc w tłumaczeniu Mac Mouse Fix. Usunięto zależność od narzędzia [BartyCrouch](https://github.com/FlineDev/BartyCrouch), które wcześniej było używane do uzyskania części tej funkcjonalności.
- Ulepszono kilka tekstów interfejsu w języku angielskim i niemieckim.
- Wiele porządków i ulepszeń pod maską.

---

Sprawdź także informacje o wydaniu [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - największej aktualizacji Mac Mouse Fix do tej pory!