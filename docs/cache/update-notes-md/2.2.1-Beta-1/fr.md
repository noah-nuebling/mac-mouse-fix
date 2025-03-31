### Support de Ventura !
Mac Mouse Fix prend désormais entièrement en charge macOS 13 Ventura.
Remerciements particuliers à [@chamburr](https://github.com/chamburr) qui a aidé avec le support de Ventura dans l'Issue GitHub [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

### Abandon du support des anciennes versions de macOS

Malheureusement, Apple ne permet de développer _pour_ macOS 10.13 **High Sierra et versions ultérieures** que lorsqu'on développe _depuis_ macOS 13 Ventura.

Ainsi, la **version minimale supportée** est passée de 10.11 El Capitan à 10.13 High Sierra.

Je suis désolé pour cela. Mais pour vous remonter le moral, il y a une coccinelle décontractée dans la section suivante.

### Corrections de bugs 🐞
- Correction d'un plantage dans les '**Réglages par application**' lors de l'ajout d'une application sans 'Bundle ID'. Pourrait aider avec les Issues GitHub [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289) et [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241).
- Correction d'un problème où Mac Mouse Fix modifiait le comportement de défilement de certaines **tablettes graphiques**. Voir l'Issue GitHub [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Correction d'un problème où les **raccourcis clavier** incluant la touche 'A' ne pouvaient pas être enregistrés. Corrige l'Issue GitHub [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Correction d'un problème où certaines **réaffectations** de boutons ne fonctionnaient pas correctement avec une disposition de clavier non standard.
- **Autres** petites corrections et améliorations visuelles.