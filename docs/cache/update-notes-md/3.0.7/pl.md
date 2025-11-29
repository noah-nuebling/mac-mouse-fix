Mac Mouse Fix **3.0.7** naprawia kilka ważnych błędów.

### Poprawki błędów

- Aplikacja ponownie działa na **starszych wersjach macOS** (macOS 10.15 Catalina i macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 nie mógł być włączony w tych wersjach macOS, ponieważ ulepszona funkcja „Wstecz" i „Dalej" wprowadzona w Mac Mouse Fix 3.0.6 próbowała użyć systemowych API macOS, które nie były dostępne.
- Naprawiono problemy z funkcją **„Wstecz" i „Dalej"**
    - Ulepszona funkcja „Wstecz" i „Dalej" wprowadzona w Mac Mouse Fix 3.0.6 będzie teraz zawsze używać „głównego wątku" do zapytania macOS o to, które naciśnięcia klawiszy symulować, aby cofnąć się lub przejść dalej w aplikacji, której używasz. \
    To może zapobiec awariom i nieprzewidywalnemu zachowaniu w niektórych sytuacjach.
- Podjęto próbę naprawienia błędu, w którym **ustawienia były losowo resetowane** (Zobacz te [problemy na GitHubie](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Przepisałem kod ładujący plik konfiguracyjny Mac Mouse Fix, aby był bardziej odporny. Gdy występowały rzadkie błędy systemu plików macOS, stary kod mógł czasami błędnie uznać, że plik konfiguracyjny jest uszkodzony i zresetować go do ustawień domyślnych.
- Zmniejszono prawdopodobieństwo błędu, w którym **przewijanie przestaje działać**     
     - Ten błąd nie może być w pełni rozwiązany bez głębszych zmian, które prawdopodobnie spowodowałyby inne problemy. \
      Jednak na razie zmniejszyłem okno czasowe, w którym może wystąpić „zakleszczenie" w systemie przewijania, co powinno przynajmniej obniżyć szanse na napotkanie tego błędu. To również sprawia, że przewijanie jest nieco bardziej wydajne. 
    - Ten błąd ma podobne objawy – ale myślę, że inną przyczynę – do błędu „Przewijanie przestaje działać sporadycznie", który został rozwiązany w poprzednim wydaniu 3.0.6.
    - (Dzięki Joonasowi za diagnostykę!) 

Dziękuję wszystkim za zgłaszanie błędów! 

---

Sprawdź również poprzednie wydanie [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).