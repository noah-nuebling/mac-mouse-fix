Mac Mouse Fix **3.0.6** zpřístupňuje funkci 'Zpět' a 'Vpřed' pro více aplikací.
Také řeší několik chyb a problémů.

### Vylepšená funkce 'Zpět' a 'Vpřed'

Mapování tlačítek myši 'Zpět' a 'Vpřed' nyní **funguje ve více aplikacích**, včetně:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed a dalších editorů kódu
- Mnoha vestavěných aplikací Apple, jako jsou Náhled, Poznámky, Nastavení systému, App Store a Hudba
- Adobe Acrobat
- Zotero
- A dalších!

Implementace je inspirována skvělou funkcí 'Universal Back and Forward' v [LinearMouse](https://github.com/linearmouse/linearmouse). Měla by podporovat všechny aplikace, které podporuje LinearMouse. \
Navíc podporuje některé aplikace, které normálně vyžadují klávesové zkratky pro přechod zpět a vpřed, jako jsou Nastavení systému, App Store, Apple Poznámky a Adobe Acrobat. Mac Mouse Fix nyní tyto aplikace rozpozná a simuluje příslušné klávesové zkratky.

Každá aplikace, která kdy byla [požadována v GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22), by nyní měla být podporována! (Díky za zpětnou vazbu!) \
Pokud najdeš nějaké aplikace, které ještě nefungují, dej mi vědět v [žádosti o funkci](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Řešení chyby 'Posouvání přestává občas fungovat'

Někteří uživatelé zaznamenali [problém](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22), kdy **plynulé posouvání přestává náhodně fungovat**.

I když se mi tento problém nikdy nepodařilo reprodukovat, implementoval jsem potenciální opravu:

Aplikace nyní bude opakovat několikrát pokus o nastavení synchronizace s displejem, pokud selže. \
Pokud to ani po opakování nebude fungovat, aplikace:

- Restartuje proces na pozadí 'Mac Mouse Fix Helper', což může problém vyřešit
- Vytvoří hlášení o pádu, které může pomoci diagnostikovat chybu

Doufám, že je problém nyní vyřešen! Pokud ne, dej mi vědět v [hlášení chyby](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) nebo přes [email](http://redirect.macmousefix.com/?target=mailto-noah).



### Vylepšené chování volně se točícího kolečka myši

Mac Mouse Fix už **nebude zrychlovat posouvání**, když necháš kolečko myši volně se točit na myši MX Master. (Nebo na jakékoli jiné myši s volně se točícím kolečkem.)

I když je tato funkce 'zrychlení posouvání' užitečná u běžných kolečkových myší, u volně se točícího kolečka může ztížit ovládání.

**Poznámka:** Mac Mouse Fix momentálně není plně kompatibilní s většinou myší Logitech, včetně MX Master. Plánuji přidat plnou podporu, ale pravděpodobně to chvíli potrvá. Mezitím je nejlepší ovladač třetí strany s podporou Logitech, který znám, [SteerMouse](https://plentycom.jp/en/steermouse/).





### Opravy chyb

- Opraven problém, kdy Mac Mouse Fix někdy znovu povolil klávesové zkratky, které byly dříve zakázány v Nastavení systému  
- Opraven pád při kliknutí na 'Aktivovat licenci' 
- Opraven pád při kliknutí na 'Zrušit' hned po kliknutí na 'Aktivovat licenci' (Díky za hlášení, Ali!)
- Opraveny pády při pokusu o použití Mac Mouse Fix, když není k Macu připojen žádný displej 
- Opraven únik paměti a některé další interní problémy při přepínání mezi kartami v aplikaci 

### Vizuální vylepšení

- Opraven problém, kdy byla karta O aplikaci někdy příliš vysoká, což bylo zavedeno ve verzi [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Text v oznámení 'Bezplatné dny skončily' už není oříznutý v čínštině
- Opraven vizuální problém se stínem pole '+' po zaznamenání vstupu
- Opravena vzácná chyba, kdy se zástupný text na obrazovce 'Zadej svůj licenční klíč' zobrazoval mimo střed
- Opraven problém, kdy některé symboly zobrazené v aplikaci měly špatnou barvu po přepnutí mezi tmavým/světlým režimem

### Další vylepšení

- Některé animace, jako je animace přepínání karet, byly mírně zefektivněny  
- Zakázáno automatické dokončování textu Touch Baru na obrazovce 'Zadej svůj licenční klíč' 
- Různá menší interní vylepšení

*Upraveno s vynikající asistencí Claude.*

---

Podívej se také na předchozí vydání [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).