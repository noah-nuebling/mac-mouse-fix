Mac Mouse Fix **3.0.4** poprawia prywatność, wydajność i niezawodność.\
Wprowadza nowy system licencjonowania offline i naprawia kilka ważnych błędów.

### Ulepszona prywatność i wydajność

Wersja 3.0.4 wprowadza nowy system walidacji licencji offline, który minimalizuje połączenia internetowe tak bardzo, jak to możliwe.\
To poprawia prywatność i oszczędza zasoby systemowe twojego komputera.\
Gdy aplikacja jest licencjonowana, działa teraz w 100% offline!

<details>
<summary><b>Kliknij tutaj, aby zobaczyć więcej szczegółów</b></summary>
Poprzednie wersje walidowały licencje online przy każdym uruchomieniu, potencjalnie pozwalając na przechowywanie logów połączeń przez serwery stron trzecich (GitHub i Gumroad). Nowy system eliminuje niepotrzebne połączenia – po początkowej aktywacji licencji łączy się z internetem tylko wtedy, gdy lokalne dane licencji są uszkodzone.
<br><br>
Chociaż żadne zachowania użytkowników nigdy nie były rejestrowane przeze mnie osobiście, poprzedni system teoretycznie pozwalał serwerom stron trzecich na logowanie adresów IP i czasów połączeń. Gumroad mógł również logować twój klucz licencyjny i potencjalnie korelować go z wszelkimi danymi osobowymi, które zarejestrowali o tobie podczas zakupu Mac Mouse Fix.
<br><br>
Nie brałem pod uwagę tych subtelnych kwestii prywatności, gdy budowałem oryginalny system licencjonowania, ale teraz Mac Mouse Fix jest tak prywatny i niezależny od internetu, jak to tylko możliwe!
<br><br>
Zobacz także <a href=https://gumroad.com/privacy>politykę prywatności Gumroad</a> i ten mój <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>komentarz na GitHubie</a>.

</details>

### Poprawki błędów

- Naprawiono błąd, przez który macOS czasami się zawieszał podczas używania 'Kliknij i przeciągnij' dla 'Spaces i Mission Control'.
- Naprawiono błąd, przez który skróty klawiszowe w Ustawieniach systemowych czasami były usuwane podczas używania akcji 'Kliknięcie' w Mac Mouse Fix, takich jak 'Mission Control'.
- Naprawiono [błąd](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22), przez który aplikacja czasami przestawała działać i pokazywała powiadomienie, że 'Darmowe dni się skończyły' użytkownikom, którzy już kupili aplikację.
    - Jeśli doświadczyłeś tego błędu, szczerze przepraszam za niedogodności. Możesz ubiegać się o [zwrot pieniędzy tutaj](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Ulepszono sposób, w jaki aplikacja pobiera swoje główne okno, co mogło naprawić błąd, przez który ekran 'Aktywuj licencję' czasami nie pojawiał się.

### Ulepszenia użyteczności

- Uniemożliwiono wprowadzanie spacji i znaków nowej linii w polu tekstowym na ekranie 'Aktywuj licencję'.
    - To był częsty punkt zamieszania, ponieważ bardzo łatwo jest przypadkowo zaznaczyć ukryty znak nowej linii podczas kopiowania klucza licencyjnego z e-maili Gumroad.
- Te notatki aktualizacji są automatycznie tłumaczone dla użytkowników nieposługujących się językiem angielskim (Napędzane przez Claude). Mam nadzieję, że to pomocne! Jeśli napotkasz jakiekolwiek problemy, daj mi znać. To pierwszy rzut oka na nowy system tłumaczeń, który rozwijam od ponad roku.

### Zakończenie (nieoficjalnego) wsparcia dla macOS 10.14 Mojave

Mac Mouse Fix 3 oficjalnie wspiera macOS 11 Big Sur i nowsze. Jednak dla użytkowników gotowych zaakceptować pewne usterki i problemy graficzne, Mac Mouse Fix 3.0.3 i wcześniejsze wersje mogły być nadal używane na macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 kończy to wsparcie i **teraz wymaga macOS 10.15 Catalina**.\
Przepraszam za wszelkie niedogodności z tym związane. Ta zmiana pozwoliła mi zaimplementować ulepszony system licencjonowania przy użyciu nowoczesnych funkcji Swift. Użytkownicy Mojave mogą nadal używać Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) lub [najnowszej wersji Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Mam nadzieję, że to dobre rozwiązanie dla wszystkich.

### Ulepszenia pod maską

- Zaimplementowano nowy system 'MFDataClass' pozwalający na bardziej zaawansowane modelowanie danych przy jednoczesnym zachowaniu czytelności i edytowalności pliku konfiguracyjnego Mac Mouse Fix przez człowieka.
- Zbudowano wsparcie dla dodawania platform płatności innych niż Gumroad. Więc w przyszłości mogą pojawić się zlokalizowane kasy, a aplikacja może być sprzedawana w różnych krajach.
- Ulepszone logowanie, które pozwala mi tworzyć bardziej efektywne "Wersje debugowania" dla użytkowników, którzy doświadczają trudnych do odtworzenia błędów.
- Wiele innych drobnych ulepszeń i prac porządkowych.

*Edytowane z doskonałą pomocą Claude.*

---

Sprawdź także poprzednie wydanie [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).