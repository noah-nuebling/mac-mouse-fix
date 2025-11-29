Mac Mouse Fix **3.0.4** vylepšuje soukromí, efektivitu a spolehlivost.\
Zavádí nový offline licenční systém a opravuje několik důležitých chyb.

### Vylepšené soukromí a efektivita

Verze 3.0.4 zavádí nový offline systém ověřování licencí, který minimalizuje připojení k internetu, jak jen je to možné.\
To zlepšuje soukromí a šetří systémové prostředky tvého počítače.\
Když je aplikace licencovaná, nyní funguje 100% offline!

<details>
<summary><b>Klikni sem pro více informací</b></summary>
Předchozí verze ověřovaly licence online při každém spuštění, což potenciálně umožňovalo ukládání záznamů o připojení na serverech třetích stran (GitHub a Gumroad). Nový systém eliminuje zbytečná připojení – po počáteční aktivaci licence se připojuje k internetu pouze v případě, že jsou lokální licenční data poškozená.
<br><br>
I když jsem osobně nikdy nezaznamenával chování uživatelů, předchozí systém teoreticky umožňoval serverům třetích stran zaznamenávat IP adresy a časy připojení. Gumroad mohl také zaznamenávat tvůj licenční klíč a potenciálně ho korelovat s jakýmikoli osobními údaji, které o tobě zaznamenal při nákupu Mac Mouse Fix.
<br><br>
Při vytváření původního licenčního systému jsem tyto jemné problémy se soukromím nebral v úvahu, ale nyní je Mac Mouse Fix tak soukromý a nezávislý na internetu, jak jen je to možné!
<br><br>
Viz také <a href=https://gumroad.com/privacy>zásady ochrany soukromí Gumroad</a> a tento můj <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>komentář na GitHubu</a>.

</details>

### Opravy chyb

- Opravena chyba, kdy se macOS někdy zasekl při používání 'Kliknutí a přetažení' pro 'Plochy a Mission Control'.
- Opravena chyba, kdy se klávesové zkratky v Nastavení systému někdy smazaly při používání akcí 'Kliknutí' v Mac Mouse Fix, jako je 'Mission Control'.
- Opravena [chyba](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22), kdy aplikace někdy přestala fungovat a zobrazila oznámení, že 'Zkušební dny skončily' uživatelům, kteří si aplikaci již koupili.
    - Pokud jsi tuto chybu zažil, upřímně se omlouvám za nepříjemnosti. Můžeš požádat o [vrácení peněz zde](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Vylepšen způsob, jakým aplikace získává své hlavní okno, což mohlo opravit chybu, kdy se obrazovka 'Aktivovat licenci' někdy nezobrazila.

### Vylepšení použitelnosti

- Znemožněno zadávání mezer a zalomení řádků do textového pole na obrazovce 'Aktivovat licenci'.
    - To byl častý zdroj zmatku, protože je velmi snadné při kopírování licenčního klíče z e-mailů Gumroad omylem vybrat skryté zalomení řádku.
- Tyto poznámky k aktualizaci jsou automaticky přeloženy pro uživatele, kteří nemluví anglicky (využívá Claude). Doufám, že to bude užitečné! Pokud s tím narazíš na nějaké problémy, dej mi vědět. Toto je první pohled na nový překladový systém, který vyvíjím už rok.

### Ukončena (neoficiální) podpora pro macOS 10.14 Mojave

Mac Mouse Fix 3 oficiálně podporuje macOS 11 Big Sur a novější. Nicméně pro uživatele ochotné akceptovat některé závady a grafické problémy bylo možné Mac Mouse Fix 3.0.3 a starší stále používat na macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 tuto podporu ukončuje a **nyní vyžaduje macOS 10.15 Catalina**. \
Omlouvám se za jakékoli nepříjemnosti tím způsobené. Tato změna mi umožnila implementovat vylepšený licenční systém pomocí moderních funkcí Swift. Uživatelé Mojave mohou nadále používat Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) nebo [nejnovější verzi Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Doufám, že je to pro všechny dobré řešení.

### Vylepšení pod kapotou

- Implementován nový systém 'MFDataClass' umožňující výkonnější modelování dat při zachování čitelnosti a editovatelnosti konfiguračního souboru Mac Mouse Fix pro člověka.
- Vytvořena podpora pro přidání dalších platebních platforem kromě Gumroad. Takže v budoucnu by mohly být lokalizované pokladny a aplikace by mohla být prodávána do různých zemí.
- Vylepšeno logování, které mi umožňuje vytvářet efektivnější "Debug Buildy" pro uživatele, kteří zažívají těžko reprodukovatelné chyby.
- Mnoho dalších drobných vylepšení a úklidových prací.

*Upraveno s vynikající pomocí Claude.*

---

Podívej se také na předchozí vydání [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).