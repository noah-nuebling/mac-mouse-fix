Mac Mouse Fix **3.0.1** kommer med flera buggfixar och förbättringar, samt ett **nytt språk**!

### Vietnamesiska har lagts till!

Mac Mouse Fix finns nu tillgängligt på 🇻🇳 vietnamesiska. Stort tack till @nghlt [på GitHub](https://GitHub.com/nghlt)!

### Buggfixar

- Mac Mouse Fix fungerar nu korrekt med **Snabbt användarbyte**!
  - Snabbt användarbyte är när du loggar in på ett andra macOS-konto utan att logga ut från det första kontot.
  - Före denna uppdatering slutade scrollning fungera efter ett snabbt användarbyte. Nu borde allt fungera korrekt.
- Fixade en mindre bugg där layouten för Knappar-fliken var för bred efter att ha startat Mac Mouse Fix för första gången.
- Gjorde '+'-fältet mer pålitligt när flera Åtgärder läggs till i snabb följd.
- Fixade en ovanlig krasch rapporterad av @V-Coba i Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Andra förbättringar

- **Scrollning känns mer responsiv** när inställningen 'Mjukhet: Normal' används.
  - Animationshastigheten blir nu snabbare när du rullar scrollhjulet snabbare. På så sätt känns det mer responsivt när du scrollar snabbt samtidigt som det känns lika mjukt när du scrollar långsamt.

- Gjorde **scrollhastighetens acceleration** mer stabil och förutsägbar.
- Implementerade en mekanism för att **behålla dina inställningar** när du uppdaterar till en ny version av Mac Mouse Fix.
  - Tidigare återställde Mac Mouse Fix alla dina inställningar efter uppdatering till en ny version om inställningsstrukturen ändrades. Nu kommer Mac Mouse Fix att försöka uppgradera strukturen på dina inställningar och behålla dina preferenser.
  - Hittills fungerar detta endast vid uppdatering från 3.0.0 till 3.0.1. Om du uppdaterar från en äldre version än 3.0.0, eller om du _nedgraderar_ från 3.0.1 _till_ en tidigare version, kommer dina inställningar fortfarande att återställas.
- Layouten för Knappar-fliken anpassar nu sin bredd bättre till olika språk.
- Förbättringar av [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) och andra dokument.
- Förbättrade lokaliseringssystem. Översättningsfilerna rensas nu automatiskt och analyseras för potentiella problem. Det finns en ny [Lokaliseringsguide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) som visar automatiskt upptäckta problem tillsammans med annan användbar information och instruktioner för personer som vill hjälpa till att översätta Mac Mouse Fix. Tog bort beroendet av verktyget [BartyCrouch](https://github.com/FlineDev/BartyCrouch) som tidigare användes för att få en del av denna funktionalitet.
- Förbättrade flera UI-strängar på engelska och tyska.
- Massor av interna förbättringar och upprensningar.

---

Kolla även in releaseinformationen för [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - den största uppdateringen av Mac Mouse Fix hittills!