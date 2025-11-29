Mac Mouse Fix **3.0.8** rozwiązuje problemy z interfejsem i nie tylko.

### **Problemy z interfejsem**

- Wyłączono nowy design w macOS 26 Tahoe. Teraz aplikacja będzie wyglądać i działać tak jak w macOS 15 Sequoia. 
    - Zrobiłem to, ponieważ niektóre przeprojektowane przez Apple elementy interfejsu wciąż mają problemy. Na przykład przyciski '-' w zakładce 'Przyciski' nie zawsze były klikalne.
    - Interfejs może teraz wyglądać trochę przestarzale w macOS 26 Tahoe. Ale powinien być w pełni funkcjonalny i dopracowany jak wcześniej.
- Naprawiono błąd, przez który powiadomienie 'Darmowe dni się skończyły' zawieszało się w prawym górnym rogu ekranu.
    - Dzięki dla [Sashpuri](https://github.com/Sashpuri) i innych za zgłoszenie!

### **Dopracowanie interfejsu**

- Wyłączono zielony przycisk świateł w głównym oknie Mac Mouse Fix.
    - Przycisk nic nie robił, ponieważ okno nie może być ręcznie zmieniane.
- Naprawiono problem, przez który niektóre poziome linie w tabeli w zakładce 'Przyciski' były zbyt ciemne w macOS 26 Tahoe.
- Naprawiono błąd, przez który komunikat "Główny przycisk myszy nie może być użyty" w zakładce 'Przyciski' był czasami obcięty w macOS 26 Tahoe.
- Naprawiono literówkę w interfejsie niemieckim. Dzięki uprzejmości użytkownika GitHub [i-am-the-slime](https://github.com/i-am-the-slime). Dzięki!
- Rozwiązano problem, przez który okno MMF czasami krótko migało w niewłaściwym rozmiarze podczas otwierania okna w macOS 26 Tahoe.

### **Inne zmiany**

- Poprawiono zachowanie podczas próby włączenia Mac Mouse Fix, gdy na komputerze działa wiele instancji Mac Mouse Fix. 
    - Mac Mouse Fix będzie teraz bardziej wytrwale próbował wyłączyć inną instancję Mac Mouse Fix. 
    - Może to poprawić przypadki brzegowe, w których Mac Mouse Fix nie mógł być włączony.
- Zmiany i porządki pod maską.

---

Sprawdź też, co nowego w poprzedniej wersji [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).