Mac Mouse Fix **3.0.8** řeší problémy s uživatelským rozhraním a další.

### **Problémy s uživatelským rozhraním**

- Zakázán nový design v macOS 26 Tahoe. Aplikace nyní bude vypadat a fungovat jako v macOS 15 Sequoia. 
    - Udělal jsem to, protože některé z Applem přepracovaných prvků uživatelského rozhraní stále mají problémy. Například tlačítka '-' na kartě 'Tlačítka' nebyla vždy klikatelná.
    - Uživatelské rozhraní může nyní v macOS 26 Tahoe vypadat trochu zastarale. Ale mělo by být plně funkční a vyladěné jako předtím.
- Opraven bug, kdy notifikace 'Zkušební dny skončily' zůstala zaseknutá v pravém horním rohu obrazovky.
    - Díky [Sashpuri](https://github.com/Sashpuri) a dalším za nahlášení!

### **Vylepšení uživatelského rozhraní**

- Zakázáno zelené tlačítko semafor v hlavním okně Mac Mouse Fix.
    - Tlačítko nedělalo nic, protože okno nelze ručně měnit velikost.
- Opraven problém, kdy některé vodorovné čáry v tabulce na kartě 'Tlačítka' byly příliš tmavé v macOS 26 Tahoe.
- Opraven bug, kdy zpráva "Primární tlačítko myši nelze použít" na kartě 'Tlačítka' byla někdy oříznutá v macOS 26 Tahoe.
- Opraven překlep v německém rozhraní. S přispěním uživatele GitHubu [i-am-the-slime](https://github.com/i-am-the-slime). Díky!
- Vyřešen problém, kdy okno MMF někdy krátce bliklo ve špatné velikosti při otevírání okna v macOS 26 Tahoe.

### **Další změny**

- Vylepšeno chování při pokusu o povolení Mac Mouse Fix, když na počítači běží více instancí Mac Mouse Fix. 
    - Mac Mouse Fix se nyní bude pečlivěji snažit zakázat další instanci Mac Mouse Fix. 
    - To může zlepšit okrajové případy, kdy Mac Mouse Fix nemohl být povolen.
- Změny a úklid pod kapotou.

---

Podívej se také, co je nového v předchozí verzi [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).