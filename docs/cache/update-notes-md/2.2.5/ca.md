Mac Mouse Fix **2.2.5** inclou millores en el mecanisme d'actualització i està preparat per a macOS 15 Sequoia!

### Nou marc d'actualització Sparkle

Mac Mouse Fix utilitza el marc d'actualització [Sparkle](https://sparkle-project.org/) per ajudar a proporcionar una gran experiència d'actualització.

Amb la versió 2.2.5, Mac Mouse Fix canvia d'utilitzar Sparkle 1.26.0 a l'última versió [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), que conté correccions de seguretat, millores de localització i més.

### Mecanisme d'actualització més intel·ligent

Hi ha un nou mecanisme que decideix quina actualització mostrar a l'usuari. El comportament ha canviat de les següents maneres:

1. Després d'ometre una actualització **major** (com ara 2.2.5 -> 3.0.0), encara se't notificarà de noves actualitzacions **menors** (com ara 2.2.5 -> 2.2.6).
    - Això et permet mantenir-te fàcilment en Mac Mouse Fix 2 mentre continues rebent actualitzacions, com es va discutir a l'Issue de GitHub [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. En lloc de mostrar l'actualització a l'última versió, Mac Mouse Fix ara et mostrarà l'actualització a la primera versió de l'última versió major.
    - Exemple: Si estàs utilitzant MMF 2.2.5, i MMF 3.4.5 és l'última versió, l'aplicació ara et mostrarà la primera versió de MMF 3 (3.0.0), en lloc de l'última versió (3.4.5). D'aquesta manera, tots els usuaris de MMF 2.2.5 veuran el registre de canvis de MMF 3.0.0 abans de canviar a MMF 3.
    - Discussió:
        - La principal motivació darrere d'això és que, a principis d'aquest any, molts usuaris de MMF 2 van actualitzar directament de MMF 2 a MMF 3.0.1 o 3.0.2. Com que mai van veure el registre de canvis de 3.0.0, es van perdre qualsevol informació sobre els canvis de preus entre MMF 2 i MMF 3 (MMF 3 ja no és 100% gratuït). Així que quan MMF 3 de sobte els va dir que havien de pagar per continuar utilitzant l'aplicació, alguns estaven - comprensiblement - una mica confosos i molestos.
        - Desavantatge: Si només vols actualitzar a l'última versió, ara hauràs d'actualitzar dues vegades en alguns casos. Això és lleugerament ineficient, però encara hauria de trigar només uns segons. I com que això fa que els canvis entre versions majors siguin molt més transparents, crec que és un compromís raonable.

### Suport per a macOS 15 Sequoia

Mac Mouse Fix 2.2.5 funcionarà perfectament en el nou macOS 15 Sequoia - igual que ho feia el 2.2.4.

---

També pots consultar la versió anterior [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Si tens problemes per activar Mac Mouse Fix després d'actualitzar, consulta la [Guia 'Activant Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*