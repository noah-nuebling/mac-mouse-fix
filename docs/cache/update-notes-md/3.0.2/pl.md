Mac Mouse Fix **3.0.2** wprowadza kilka ulepszeń, w tym **płynniejsze przewijanie**, poprawione tłumaczenia i więcej!

### Przewijanie

- Możesz teraz zatrzymać animacje przewijania, przewijając jeden krok w przeciwnym kierunku. Pozwala to na **'rzucanie'** i **'łapanie strony'** podczas korzystania z opcji 'Płynność: Wysoka', podobnie jak na gładziku.
- Mac Mouse Fix wysyła teraz zdarzenia przewijania wcześniej w cyklu odświeżania wyświetlacza, dając aplikacjom więcej czasu na przetworzenie zdarzeń przewijania i płynne wyświetlanie. To **poprawia liczbę klatek**, szczególnie na złożonych stronach jak YouTube.com.
- Poprawiono responsywność ustawienia 'Płynność: Wysoka', ułatwiając kontrolę nad przewijaniem.
- Ulepszono mechanizm wprowadzony w wersji 3.0.1, w którym prędkość animacji zwiększa się wraz z szybszym ruchem kółka przewijania przy użyciu 'Płynność: Standardowa'. W wersji 3.0.2 przyspieszenie animacji powinno być bardziej spójne i przewidywalne, co ułatwia obserwację przy zachowaniu świetnej kontroli.
- Naprawiono problem, w którym prędkość przewijania była zbyt wolna, szczególnie przy użyciu opcji 'Precyzja'. Problem ten został wprowadzony w wersji 3.0.1. Podziękowania dla @V-Coba za zwrócenie na to uwagi w [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- Poprawiono zachowanie w przeglądarce Arc podczas używania 'Kliknij i Przewiń' do 'Przybliżania i Oddalania'.

### Lokalizacja

- Zaktualizowano tłumaczenia 🇻🇳 wietnamskie. Podziękowania dla @nghlt!
- Poprawiono niektóre tłumaczenia 🇩🇪 niemieckie.
- Tekst w Mac Mouse Fix, który nie ma tłumaczenia dla aktualnego języka, będzie teraz pokazywał wartość zastępczą zamiast pozostawać pustym. Powinno to ułatwić nawigację w aplikacji w przypadku brakujących tłumaczeń.

### Inne

- Mac Mouse Fix będzie teraz wyświetlał powiadomienie z linkiem do [tego przewodnika](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) użytkownikom, którzy mogą doświadczać błędu w macOS 13 Ventura i nowszych wersjach, który może uniemożliwiać włączenie Mac Mouse Fix.
- Zmieniono domyślne ustawienia dla myszy z 3 przyciskami. Domyślne ustawienia nie zawierają już akcji 'Kliknij i Przewiń' dla przycisku kółka przewijania, ponieważ jest to dość trudne do wykonania. Zamiast tego, domyślne ustawienia zawierają teraz akcje 'Przytrzymaj' i 'Podwójne Kliknięcie'.
- Dodano podpowiedź do ikony Mac Mouse Fix w zakładce O programie. Informuje ona, jak pokazać plik konfiguracyjny Mac Mouse Fix w Finderze.
- Wiele porządków i ulepszeń pod maską.

---

Sprawdź również poprzednie wydanie [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).