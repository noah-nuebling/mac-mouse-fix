Mac Mouse Fix **2.2.5** innehåller förbättringar av uppdateringsmekanismen och är redo för macOS 15 Sequoia!

### Nytt Sparkle-uppdateringsramverk

Mac Mouse Fix använder [Sparkle](https://sparkle-project.org/)-uppdateringsramverket för att ge en bra uppdateringsupplevelse.

Med 2.2.5 byter Mac Mouse Fix från Sparkle 1.26.0 till senaste Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), som innehåller säkerhetsuppdateringar, lokaliseringsförbättringar och mer.

### Smartare uppdateringsmekanism

Det finns en ny mekanism som avgör vilken uppdatering som visas för användaren. Beteendet har ändrats på följande sätt:

1. Efter att du hoppar över en **större** uppdatering (som 2.2.5 -> 3.0.0), kommer du fortfarande att meddelas om nya **mindre** uppdateringar (som 2.2.5 -> 2.2.6).
    - Detta gör att du enkelt kan stanna kvar på Mac Mouse Fix 2 medan du fortfarande får uppdateringar, som diskuterat i GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Istället för att visa uppdateringen till den senaste versionen kommer Mac Mouse Fix nu att visa uppdateringen till den första versionen av den senaste större versionen.
    - Exempel: Om du använder MMF 2.2.5, och MMF 3.4.5 är den senaste versionen, kommer appen nu att visa dig den första versionen av MMF 3 (3.0.0), istället för den senaste versionen (3.4.5). På detta sätt ser alla MMF 2.2.5-användare MMF 3.0.0-ändringsloggen innan de byter till MMF 3.
    - Diskussion:
        - Huvudmotivationen bakom detta är att tidigare i år uppdaterade många MMF 2-användare direkt från MMF 2 till MMF 3.0.1 eller 3.0.2. Eftersom de aldrig såg 3.0.0-ändringsloggen missade de information om prisändringarna mellan MMF 2 och MMF 3 (MMF 3 är inte längre 100% gratis). Så när MMF 3 plötsligt sa att de behövde betala för att fortsätta använda appen blev några - förståeligt nog - lite förvirrade och upprörda.
        - Nackdel: Om du bara vill uppdatera till den senaste versionen måste du nu uppdatera två gånger i vissa fall. Detta är något ineffektivt, men det bör fortfarande bara ta några sekunder. Och eftersom detta gör ändringarna mellan större versioner mycket mer transparenta, tror jag det är en rimlig kompromiss.

### Stöd för macOS 15 Sequoia

Mac Mouse Fix 2.2.5 kommer att fungera utmärkt på nya macOS 15 Sequoia - precis som 2.2.4 gjorde.

---

Kolla även in den tidigare versionen [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Om du har problem med att aktivera Mac Mouse Fix efter uppdateringen, kolla guiden ['Enabling Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*