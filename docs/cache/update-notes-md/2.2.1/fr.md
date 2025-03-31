Mac Mouse Fix **2.2.1** offre une **prise en charge complète de macOS Ventura** parmi d'autres changements.

### Prise en charge de Ventura !
Mac Mouse Fix prend désormais entièrement en charge macOS 13 Ventura et s'intègre naturellement.
Remerciements particuliers à [@chamburr](https://github.com/chamburr) qui a aidé avec la prise en charge de Ventura dans l'Issue GitHub [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Les changements incluent :

- Mise à jour de l'interface pour l'accès aux paramètres d'accessibilité reflétant les nouveaux Réglages Système de Ventura
- Mac Mouse Fix s'affichera correctement dans le menu **Réglages Système > Ouverture** de Ventura
- Mac Mouse Fix réagira correctement lorsqu'il est désactivé dans **Réglages Système > Ouverture**

### Abandon de la prise en charge des anciennes versions de macOS

Malheureusement, Apple ne permet de développer _pour_ macOS 10.13 **High Sierra et versions ultérieures** que lors du développement _depuis_ macOS 13 Ventura.

Ainsi, la **version minimale prise en charge** est passée de 10.11 El Capitan à 10.13 High Sierra.

### Corrections de bugs

- Correction d'un problème où Mac Mouse Fix modifiait le comportement de défilement de certaines **tablettes graphiques**. Voir l'Issue GitHub [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Correction d'un problème où les **raccourcis clavier** incluant la touche 'A' ne pouvaient pas être enregistrés. Corrige l'Issue GitHub [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Correction d'un problème où certaines **réattributions de boutons** ne fonctionnaient pas correctement avec une disposition de clavier non standard.
- Correction d'un plantage dans les '**Réglages par application**' lors de l'ajout d'une application sans 'Bundle ID'. Pourrait aider avec l'Issue GitHub [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Correction d'un plantage lors de l'ajout d'applications sans nom aux '**Réglages par application**'. Résout l'Issue GitHub [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Remerciements particuliers à [jeongtae](https://github.com/jeongtae) qui a été très utile pour identifier le problème !
- Autres petites corrections de bugs et améliorations sous le capot.