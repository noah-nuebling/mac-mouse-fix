Mac Mouse Fix **3.0.4 Beta 1** vylepšuje soukromí, efektivitu a spolehlivost.\
Zavádí nový offline licenční systém a opravuje několik důležitých chyb.

### Vylepšené soukromí a efektivita

- Zavádí nový offline systém ověřování licencí, který minimalizuje připojení k internetu.
- Aplikace se nyní připojuje k internetu pouze v případě absolutní nutnosti, chrání vaše soukromí a snižuje využití zdrojů.
- Při běžném používání funguje aplikace s licencí zcela offline.

<details>
<summary><b>Podrobné informace o ochraně soukromí</b></summary>
Předchozí verze ověřovaly licence online při každém spuštění, což potenciálně umožňovalo ukládání protokolů připojení na serverech třetích stran (GitHub a Gumroad). Nový systém eliminuje zbytečná připojení – po počáteční aktivaci licence se připojuje k internetu pouze v případě, že jsou místní licenční data poškozena.
<br><br>
I když jsem osobně nikdy nezaznamenával chování uživatelů, předchozí systém teoreticky umožňoval serverům třetích stran zaznamenávat IP adresy a časy připojení. Gumroad mohl také zaznamenávat váš licenční klíč a potenciálně jej propojit s osobními údaji, které o vás zaznamenal při nákupu Mac Mouse Fix.
<br><br>
Při vytváření původního licenčního systému jsem tyto jemné problémy se soukromím nebral v úvahu, ale nyní je Mac Mouse Fix maximálně soukromý a nezávislý na internetu!
<br><br>
Podívejte se také na <a href=https://gumroad.com/privacy>zásady ochrany soukromí Gumroad</a> a můj <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>komentář na GitHubu</a>.

</details>

### Opravy chyb

- Opravena chyba, kdy macOS někdy zamrzl při používání funkce 'Kliknutí a přetažení' pro 'Spaces & Mission Control'.
- Opravena chyba, kdy se klávesové zkratky v Systémových nastaveních někdy smazaly při použití akce 'Kliknutí' definované v Mac Mouse Fix, jako například 'Mission Control'.
- Opravena [chyba](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22), kdy aplikace někdy přestala fungovat a zobrazovala oznámení, že 'Zkušební dny vypršely' uživatelům, kteří si aplikaci již zakoupili.
    - Pokud jste se s touto chybou setkali, upřímně se omlouvám za nepříjemnosti. Můžete požádat o [vrácení peněz zde](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).

### Technická vylepšení

- Implementován nový systém 'MFDataClass' umožňující čistější modelování dat a konfiguračních souborů čitelných pro člověka.
- Vybudována podpora pro přidání dalších platebních platforem kromě Gumroad. Takže v budoucnu by mohly být k dispozici lokalizované platby a aplikace by se mohla prodávat do různých zemí!

### Ukončena (neoficiální) podpora pro macOS 10.14 Mojave

Mac Mouse Fix 3 oficiálně podporuje macOS 11 Big Sur a novější. Nicméně pro uživatele, kteří byli ochotni přijmout některé chyby a grafické problémy, bylo možné Mac Mouse Fix 3.0.3 a starší verze stále používat na macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 tuto podporu ukončuje a **nyní vyžaduje macOS 10.15 Catalina**.\
Omlouvám se za případné nepříjemnosti způsobené touto změnou. Tato změna mi umožnila implementovat vylepšený licenční systém pomocí moderních funkcí Swift. Uživatelé Mojave mohou nadále používat Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) nebo [nejnovější verzi Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Doufám, že je to pro všechny dobré řešení.

*Upraveno s vynikající pomocí Claude.*

---

Podívejte se také na předchozí verzi [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).