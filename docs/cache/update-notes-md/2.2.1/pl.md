Mac Mouse Fix **2.2.1** zapewnia pełne **wsparcie dla macOS Ventura** oraz inne zmiany.

### Wsparcie dla Ventury!
Mac Mouse Fix teraz w pełni wspiera i działa natywnie z macOS 13 Ventura.
Szczególne podziękowania dla [@chamburr](https://github.com/chamburr), który pomógł we wsparciu dla Ventury w GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Zmiany obejmują:

- Zaktualizowany interfejs przyznawania Dostępu do Dostępności, aby odzwierciedlał nowe Ustawienia systemowe Ventury
- Mac Mouse Fix będzie wyświetlany prawidłowo w nowym menu Ventury **Ustawienia systemowe > Elementy logowania**
- Mac Mouse Fix będzie odpowiednio reagować, gdy zostanie wyłączony w **Ustawieniach systemowych > Elementy logowania**

### Zakończenie wsparcia dla starszych wersji macOS

Niestety, Apple pozwala na rozwój _dla_ macOS 10.13 **High Sierra i nowszych** tylko podczas programowania _z_ macOS 13 Ventura.

Dlatego **minimalna wspierana wersja** została podniesiona z 10.11 El Capitan do 10.13 High Sierra.

### Poprawki błędów

- Naprawiono problem, gdzie Mac Mouse Fix zmieniał zachowanie przewijania niektórych **tabletów graficznych**. Zobacz GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Naprawiono problem, gdzie **skróty klawiszowe** zawierające klawisz 'A' nie mogły być rejestrowane. Naprawia GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Naprawiono problem, gdzie niektóre **przypisania przycisków** nie działały prawidłowo przy użyciu niestandardowego układu klawiatury.
- Naprawiono awarię w '**Ustawieniach dla konkretnych aplikacji**' podczas próby dodania aplikacji bez 'Bundle ID'. Może pomóc z GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Naprawiono awarię podczas próby dodania aplikacji bez nazwy do '**Ustawień dla konkretnych aplikacji**'. Rozwiązuje GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Szczególne podziękowania dla [jeongtae](https://github.com/jeongtae), który był bardzo pomocny w rozwiązaniu problemu!
- Więcej drobnych poprawek błędów i ulepszeń pod maską.