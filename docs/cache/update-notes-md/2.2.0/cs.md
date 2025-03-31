Podívejte se také na **skvělé novinky** představené v [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

Mac Mouse Fix **2.2.0** přináší různá vylepšení použitelnosti a opravy chyb!

### Mapování na funkční klávesy exkluzivní pro Apple je nyní lepší

Poslední aktualizace 2.1.0 představila skvělou novou funkci, která vám umožňuje přemapovat tlačítka myši na libovolnou klávesu na klávesnici - dokonce i na funkční klávesy, které najdete pouze na klávesnicích Apple. 2.2.0 přináší další vylepšení a zdokonalení této funkce:

- Nyní můžete podržet Option (⌥) pro přemapování na klávesy, které se nachází pouze na klávesnicích Apple - i když nemáte Apple klávesnici k dispozici.
- Symboly funkčních kláves mají vylepšený vzhled a lépe zapadají do ostatního textu.
- Možnost přemapování na Caps Lock byla zakázána. Nefungovala podle očekávání.

### Snadnější přidávání / odebírání Akcí

Někteří uživatelé měli potíže zjistit, že mohou přidávat a odebírat Akce z Tabulky akcí. Pro snazší pochopení přináší verze 2.2.0 následující změny a nové funkce:

- Nyní můžete mazat Akce kliknutím pravým tlačítkem.
  - Díky tomu by mělo být snazší objevit možnost mazání Akcí.
  - Kontextová nabídka obsahuje symbol tlačítka '-'. To by mělo pomoci upozornit na tlačítko '-', které by pak mělo upozornit na tlačítko '+'. Tím by měla být možnost **přidávání** Akcí lépe objevitelná.
- Nyní můžete přidávat Akce do Tabulky akcí kliknutím pravým tlačítkem na prázdný řádek.
- Tlačítko '-' je nyní aktivní pouze když je vybrána Akce. To by mělo lépe objasnit, že tlačítko '-' maže vybranou Akci.
- Výchozí výška okna byla zvýšena tak, aby byl viditelný prázdný řádek, na který lze kliknout pravým tlačítkem pro přidání Akce.
- Tlačítka '+' a '-' mají nyní tooltips.

### Vylepšení Kliknutí a tažení

Práh pro aktivaci Kliknutí a tažení byl zvýšen z 5 pixelů na 7 pixelů. Díky tomu je těžší náhodně aktivovat Kliknutí a tažení, ale stále umožňuje uživatelům přepínat Spaces atd. pomocí malých, pohodlných pohybů.

### Další změny UI

- Byl vylepšen vzhled Tabulky akcí.
- Různá další vylepšení uživatelského rozhraní.

### Opravy chyb

- Opravena chyba, kdy UI nebylo zašedlé při spuštění MMF v zakázaném stavu.
- Odstraněna skrytá možnost "Tlačítko 3 Kliknutí a tažení".
  - Při jejím výběru aplikace padala. Tuto možnost jsem vytvořil, aby byl Mac Mouse Fix lépe kompatibilní s Blenderem. Ale v současné podobě není pro uživatele Blenderu příliš užitečná, protože ji nelze kombinovat s modifikátory klávesnice. Plánuji vylepšit kompatibilitu s Blenderem v budoucí verzi.