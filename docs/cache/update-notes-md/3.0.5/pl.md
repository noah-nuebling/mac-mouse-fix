Mac Mouse Fix **3.0.5** naprawia kilka błędów, poprawia wydajność i dodaje trochę szlifu do aplikacji. \
Jest również kompatybilny z macOS 26 Tahoe.

### Ulepszona symulacja przewijania trackpadem

- System przewijania może teraz symulować stuknięcie dwoma palcami w trackpad, aby zatrzymać przewijanie w aplikacjach.
    - Naprawia to problem występujący w aplikacjach iPhone'a lub iPada, gdzie przewijanie często kontynuowało się po tym, jak użytkownik chciał je zatrzymać.
- Naprawiono niespójną symulację odrywania palców od trackpada.
    - Mogło to powodować nieoptymalne zachowanie w niektórych sytuacjach.



### Kompatybilność z macOS 26 Tahoe

Podczas uruchamiania wersji Beta macOS 26 Tahoe aplikacja jest teraz użyteczna, a większość interfejsu działa poprawnie.



### Poprawa wydajności

Poprawiono wydajność gestu „Przewijanie i nawigacja" przy klikaniu i przeciąganiu. \
W moich testach zużycie procesora zostało zmniejszone o ~50%!

**Kontekst**

Podczas gestu „Przewijanie i nawigacja" Mac Mouse Fix rysuje fałszywy kursor myszy w przezroczystym oknie, jednocześnie blokując prawdziwy kursor myszy w miejscu. Dzięki temu możesz kontynuować przewijanie elementu interfejsu, na którym zacząłeś przewijać, bez względu na to, jak daleko przesuniesz mysz.

Poprawę wydajności osiągnięto poprzez wyłączenie domyślnej obsługi zdarzeń macOS w tym przezroczystym oknie, która i tak nie była używana.





### Poprawki błędów

- Teraz ignorowane są zdarzenia przewijania z tabletów graficznych Wacom.
    - Wcześniej Mac Mouse Fix powodował chaotyczne przewijanie na tabletach Wacom, jak zgłosił @frenchie1980 w zgłoszeniu GitHub [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Dzięki!)
    
- Naprawiono błąd, w którym kod Swift Concurrency, wprowadzony jako część nowego systemu licencjonowania w Mac Mouse Fix 3.0.4, nie działał w odpowiednim wątku.
    - Powodowało to awarie w macOS Tahoe, a także prawdopodobnie inne sporadyczne błędy związane z licencjonowaniem.
- Poprawiono odporność kodu dekodującego licencje offline.
    - Obchodzi to problem w API Apple, który powodował, że walidacja licencji offline zawsze kończyła się niepowodzeniem na moim Intel Mac Mini. Zakładam, że działo się to na wszystkich Macach z Intelem i że był to powód, dla którego błąd „Dni darmowe się skończyły" (który został już rozwiązany w 3.0.4) nadal występował u niektórych osób, jak zgłosił @toni20k5267 w zgłoszeniu GitHub [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Dziękuję!)
        - Jeśli doświadczyłeś błędu „Dni darmowe się skończyły", przepraszam za to! Możesz uzyskać zwrot pieniędzy [tutaj](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Ulepszenia UX

- Wyłączono okna dialogowe, które zapewniały krok po kroku rozwiązania błędów macOS uniemożliwiających użytkownikom włączenie Mac Mouse Fix.
    - Te problemy występowały tylko w macOS 13 Ventura i 14 Sonoma. Teraz te okna dialogowe pojawiają się tylko w tych wersjach macOS, w których są istotne. 
    - Okna dialogowe są również nieco trudniejsze do wywołania – wcześniej czasami pojawiały się w sytuacjach, w których nie były zbyt pomocne.
    
- Dodano link „Aktywuj licencję" bezpośrednio w powiadomieniu „Dni darmowe się skończyły". 
    - To sprawia, że aktywacja licencji Mac Mouse Fix jest jeszcze bardziej bezproblemowa!

### Ulepszenia wizualne

- Nieznacznie poprawiono wygląd okna „Aktualizacja oprogramowania". Teraz lepiej pasuje do macOS 26 Tahoe. 
    - Osiągnięto to poprzez dostosowanie domyślnego wyglądu frameworka „Sparkle 1.27.3", którego Mac Mouse Fix używa do obsługi aktualizacji.
- Naprawiono problem, w którym tekst na dole zakładki O programie był czasami obcięty w języku chińskim, poprzez nieznaczne poszerzenie okna.
- Naprawiono lekkie przesunięcie tekstu na dole zakładki O programie względem środka.
- Naprawiono błąd powodujący zbyt małą przestrzeń pod opcją „Skrót klawiszowy..." w zakładce Przyciski. 

### Zmiany pod maską

- Usunięto zależność od frameworka „SnapKit".
    - To nieznacznie zmniejsza rozmiar aplikacji z 19,8 do 19,5 MB.
- Różne inne drobne ulepszenia w kodzie.

*Edytowano z doskonałą pomocą Claude.*

---

Sprawdź również poprzednie wydanie [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).