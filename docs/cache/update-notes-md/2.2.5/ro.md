Mac Mouse Fix **2.2.5** aduce îmbunătățiri mecanismului de actualizare și este pregătit pentru macOS 15 Sequoia!

### Noul framework de actualizare Sparkle

Mac Mouse Fix folosește framework-ul de actualizare [Sparkle](https://sparkle-project.org/) pentru a oferi o experiență excelentă de actualizare.

Cu versiunea 2.2.5, Mac Mouse Fix trece de la Sparkle 1.26.0 la cel mai recent Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), care include remedieri de securitate, îmbunătățiri de localizare și multe altele.

### Mecanism de actualizare mai inteligent

Există un nou mecanism care decide ce actualizare să arate utilizatorului. Comportamentul s-a schimbat în următoarele moduri:

1. După ce sari peste o actualizare **majoră** (precum 2.2.5 -> 3.0.0), vei fi în continuare notificat despre actualizările **minore** noi (precum 2.2.5 -> 2.2.6).
    - Acest lucru îți permite să rămâi ușor la Mac Mouse Fix 2 în timp ce primești actualizări, așa cum s-a discutat în Issue-ul GitHub [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. În loc să arate actualizarea la cea mai recentă versiune, Mac Mouse Fix îți va arăta acum actualizarea la prima versiune din cea mai recentă versiune majoră.
    - Exemplu: Dacă folosești MMF 2.2.5, și MMF 3.4.5 este cea mai recentă versiune, aplicația îți va arăta acum prima versiune din MMF 3 (3.0.0), în loc de ultima versiune (3.4.5). Astfel, toți utilizatorii MMF 2.2.5 vor vedea changelog-ul MMF 3.0.0 înainte de a trece la MMF 3.
    - Discuție:
        - Motivația principală este că, la începutul acestui an, mulți utilizatori MMF 2 au actualizat direct de la MMF 2 la MMF 3.0.1 sau 3.0.2. Deoarece nu au văzut niciodată changelog-ul 3.0.0, au ratat informațiile despre modificările de preț între MMF 2 și MMF 3 (MMF 3 nu mai este 100% gratuit). Așa că atunci când MMF 3 le-a spus brusc că trebuie să plătească pentru a continua să folosească aplicația, unii au fost - pe bună dreptate - puțin confuzi și supărați.
        - Dezavantaj: Dacă vrei doar să actualizezi la cea mai recentă versiune, va trebui acum să actualizezi de două ori în unele cazuri. Este puțin ineficient, dar ar trebui să dureze tot doar câteva secunde. Și pentru că face modificările între versiunile majore mult mai transparente, cred că este un compromis rezonabil.

### Suport pentru macOS 15 Sequoia

Mac Mouse Fix 2.2.5 va funcționa excelent pe noul macOS 15 Sequoia - la fel ca și 2.2.4.

---

Vezi și versiunea anterioară [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Dacă ai probleme cu activarea Mac Mouse Fix după actualizare, te rugăm să consulți [Ghidul 'Activare Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*