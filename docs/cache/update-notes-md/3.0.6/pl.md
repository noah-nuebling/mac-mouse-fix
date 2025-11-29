Mac Mouse Fix **3.0.6** sprawia, że funkcja „Wstecz" i „Dalej" jest kompatybilna z większą liczbą aplikacji.
Naprawia również kilka błędów i problemów.

### Ulepszona funkcja „Wstecz" i „Dalej"

Mapowania przycisków myszy „Wstecz" i „Dalej" teraz **działają w większej liczbie aplikacji**, w tym:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed i innych edytorach kodu
- Wielu wbudowanych aplikacjach Apple, takich jak Podgląd, Notatki, Ustawienia systemowe, App Store i Muzyka
- Adobe Acrobat
- Zotero
- I wielu innych!

Implementacja jest zainspirowana świetną funkcją „Universal Back and Forward" w [LinearMouse](https://github.com/linearmouse/linearmouse). Powinna obsługiwać wszystkie aplikacje, które obsługuje LinearMouse. \
Ponadto obsługuje niektóre aplikacje, które normalnie wymagają skrótów klawiszowych do cofania i przechodzenia dalej, takie jak Ustawienia systemowe, App Store, Apple Notes i Adobe Acrobat. Mac Mouse Fix będzie teraz wykrywać te aplikacje i symulować odpowiednie skróty klawiszowe.

Każda aplikacja, która kiedykolwiek została [zgłoszona w GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) powinna być teraz obsługiwana! (Dzięki za feedback!) \
Jeśli znajdziesz jakieś aplikacje, które jeszcze nie działają, daj mi znać w [prośbie o funkcję](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Rozwiązanie błędu „Przewijanie przestaje działać sporadycznie"

Niektórzy użytkownicy doświadczali [problemu](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22), w którym **płynne przewijanie przestaje działać** losowo.

Chociaż nigdy nie byłem w stanie odtworzyć tego problemu, zaimplementowałem potencjalne rozwiązanie:

Aplikacja będzie teraz ponawiać próby wielokrotnie, gdy konfiguracja synchronizacji z wyświetlaczem się nie powiedzie. \
Jeśli nadal nie działa po ponownych próbach, aplikacja:

- Zrestartuje proces w tle „Mac Mouse Fix Helper", co może rozwiązać problem
- Wygeneruje raport o awarii, który może pomóc w zdiagnozowaniu błędu

Mam nadzieję, że problem jest teraz rozwiązany! Jeśli nie, daj mi znać w [raporcie o błędzie](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) lub przez [e-mail](http://redirect.macmousefix.com/?target=mailto-noah).



### Ulepszone zachowanie kółka przewijania z wolnym obracaniem

Mac Mouse Fix **nie będzie już przyspieszać przewijania**, gdy pozwolisz kółku przewijania swobodnie się obracać na myszy MX Master. (Lub jakiejkolwiek innej myszy z kółkiem przewijania z wolnym obracaniem.)

Chociaż ta funkcja „przyspieszania przewijania" jest przydatna w przypadku zwykłych kółek przewijania, w przypadku kółka z wolnym obracaniem może utrudniać kontrolę.

**Uwaga:** Mac Mouse Fix nie jest obecnie w pełni kompatybilny z większością myszy Logitech, w tym MX Master. Planuję dodać pełne wsparcie, ale prawdopodobnie zajmie to trochę czasu. W międzyczasie najlepszym sterownikiem firm trzecich z obsługą Logitech, jaki znam, jest [SteerMouse](https://plentycom.jp/en/steermouse/).





### Poprawki błędów

- Naprawiono problem, w którym Mac Mouse Fix czasami ponownie włączał skróty klawiszowe, które zostały wcześniej wyłączone w Ustawieniach systemowych
- Naprawiono awarię przy klikaniu „Aktywuj licencję"
- Naprawiono awarię przy klikaniu „Anuluj" zaraz po kliknięciu „Aktywuj licencję" (Dzięki za zgłoszenie, Ali!)
- Naprawiono awarie podczas próby użycia Mac Mouse Fix, gdy żaden wyświetlacz nie jest podłączony do Maca
- Naprawiono wyciek pamięci i kilka innych problemów pod maską podczas przełączania między zakładkami w aplikacji

### Ulepszenia wizualne

- Naprawiono problem, w którym zakładka O programie była czasami zbyt wysoka, co zostało wprowadzone w [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Tekst w powiadomieniu „Darmowe dni się skończyły" nie jest już obcięty w języku chińskim
- Naprawiono wizualny błąd w cieniu pola „+" po nagraniu wejścia
- Naprawiono rzadki błąd, w którym tekst zastępczy na ekranie „Wprowadź klucz licencyjny" pojawiał się poza centrum
- Naprawiono problem, w którym niektóre symbole wyświetlane w aplikacji miały niewłaściwy kolor po przełączeniu między trybem ciemnym/jasnym

### Inne ulepszenia

- Usprawniono niektóre animacje, takie jak animacja przełączania zakładek, czyniąc je nieco bardziej wydajnymi
- Wyłączono autouzupełnianie tekstu Touch Bar na ekranie „Wprowadź klucz licencyjny"
- Różne mniejsze ulepszenia pod maską

*Edytowane z doskonałą pomocą Claude.*

---

Sprawdź również poprzednie wydanie [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).