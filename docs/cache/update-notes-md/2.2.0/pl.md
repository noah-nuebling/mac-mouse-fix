Sprawdź też **fajne funkcje** wprowadzone w [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

Mac Mouse Fix **2.2.0** zawiera różne usprawnienia użyteczności i poprawki błędów!

### Mapowanie do klawiszy funkcyjnych Apple jest teraz lepsze

Ostatnia aktualizacja, 2.1.0, wprowadziła nową fajną funkcję, która pozwala mapować przyciski myszy do dowolnego klawisza na klawiaturze - nawet klawiszy funkcyjnych dostępnych tylko na klawiaturach Apple. Wersja 2.2.0 zawiera dalsze usprawnienia i udoskonalenia tej funkcji:

- Możesz teraz przytrzymać Option (⌥), aby mapować do klawiszy dostępnych tylko na klawiaturach Apple - nawet jeśli nie masz pod ręką klawiatury Apple.
- Symbole klawiszy funkcyjnych mają poprawiony wygląd, lepiej komponując się z pozostałym tekstem.
- Wyłączono możliwość mapowania do Caps Lock. Nie działało to zgodnie z oczekiwaniami.

### Łatwiejsze dodawanie / usuwanie Akcji

Niektórzy użytkownicy mieli problem ze zrozumieniem, że można dodawać i usuwać Akcje z Tabeli Akcji. Aby ułatwić zrozumienie, wersja 2.2.0 zawiera następujące zmiany i nowe funkcje:

- Możesz teraz usuwać Akcje klikając je prawym przyciskiem myszy.
  - To powinno ułatwić odkrycie opcji usuwania Akcji.
  - Menu prawego przycisku zawiera symbol przycisku '-'. Powinno to zwrócić uwagę na przycisk '-', który z kolei powinien zwrócić uwagę na przycisk '+'. To hopefully sprawi, że opcja **dodawania** Akcji będzie łatwiejsza do odkrycia.
- Możesz teraz dodawać Akcje do Tabeli Akcji klikając prawym przyciskiem pusty wiersz.
- Przycisk '-' jest teraz aktywny tylko wtedy, gdy Akcja jest zaznaczona. Powinno to wyraźniej pokazywać, że przycisk '-' usuwa wybraną Akcję.
- Domyślna wysokość okna została zwiększona, aby widoczny był pusty wiersz, który można kliknąć prawym przyciskiem, aby dodać Akcję.
- Przyciski '+' i '-' mają teraz podpowiedzi.

### Usprawnienia Kliknij i Przeciągnij

Próg aktywacji funkcji Kliknij i Przeciągnij został zwiększony z 5 do 7 pikseli. Utrudnia to przypadkową aktywację tej funkcji, jednocześnie pozwalając użytkownikom na przełączanie Spaces itp. za pomocą małych, wygodnych ruchów.

### Inne zmiany w interfejsie

- Poprawiono wygląd Tabeli Akcji.
- Różne inne usprawnienia interfejsu.

### Poprawki błędów

- Naprawiono problem, gdzie interfejs nie był wyszarzony przy uruchamianiu MMF w stanie wyłączonym.
- Usunięto ukrytą opcję "Przycisk 3 Kliknij i Przeciągnij".
  - Przy jej wyborze aplikacja się zawieszała. Zbudowałem tę opcję, aby poprawić kompatybilność Mac Mouse Fix z Blenderem. Jednak w obecnej formie nie jest zbyt przydatna dla użytkowników Blendera, ponieważ nie można jej łączyć z modyfikatorami klawiatury. Planuję poprawić kompatybilność z Blenderem w przyszłej wersji.