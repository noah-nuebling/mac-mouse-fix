Mac Mouse Fix **2.2.4** je nyní notarizován! Obsahuje také několik drobných oprav chyb a dalších vylepšení.

### **Notarizace**

Mac Mouse Fix 2.2.4 je nyní 'notarizován' společností Apple. To znamená, že se při prvním otevření aplikace již neobjeví zprávy o tom, že Mac Mouse Fix je potenciálně 'Škodlivý software'.

#### Pozadí

Notarizace aplikace stojí 100 $ ročně. Vždy jsem byl proti tomu, protože to působilo nepřátelsky vůči svobodnému a open source softwaru jako je Mac Mouse Fix, a také to vypadalo jako nebezpečný krok směrem k tomu, aby Apple kontroloval a uzamykal Mac stejně jako iPhony nebo iPady. Ale absence notarizace vedla k různým problémům, včetně [potíží s otevřením aplikace](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) a dokonce [několika situací](https://github.com/noah-nuebling/mac-mouse-fix/issues/95), kdy nikdo nemohl aplikaci používat, dokud jsem nevydal novou verzi.

Pro Mac Mouse Fix 3 jsem usoudil, že je konečně vhodné zaplatit 100 $ ročně za notarizaci aplikace, protože Mac Mouse Fix 3 je monetizován. ([Více informací](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Nyní získává notarizaci i Mac Mouse Fix 2, což by mělo vést k jednodušší a stabilnější uživatelské zkušenosti.

### **Opravy chyb**

- Opravena chyba, kdy kurzor zmizel a pak se znovu objevil na jiném místě při použití akce 'Kliknutí a přetažení' během nahrávání obrazovky nebo při používání softwaru [DisplayLink](https://www.synaptics.com/products/displaylink-graphics).
- Opravena chyba s povolením Mac Mouse Fix pod macOS 10.14 Mojave a možná i staršími verzemi macOS.
- Vylepšena správa paměti, potenciálně opravující pád aplikace 'Mac Mouse Fix Helper', ke kterému docházelo při odpojení myši od počítače. Viz Diskuze [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Další vylepšení**

- Okno, které aplikace zobrazuje pro informování o dostupnosti nové verze Mac Mouse Fix, nyní podporuje JavaScript. To umožňuje, aby poznámky k aktualizaci byly hezčí a lépe čitelné. Například poznámky k aktualizaci nyní mohou zobrazovat [Markdown Alerts](https://github.com/orgs/community/discussions/16925) a další.
- Odstraněn odkaz na stránku https://macmousefix.com/about/ z obrazovky "Udělit přístup k Accessibility pro Mac Mouse Fix Helper". Je to proto, že stránka About již neexistuje a byla prozatím nahrazena [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix).
- Toto vydání nyní obsahuje soubory dSYM, které může kdokoli použít k dekódování hlášení o pádech Mac Mouse Fix 2.2.4.
- Několik interních vylepšení a úprav.

---

Podívejte se také na předchozí vydání [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).