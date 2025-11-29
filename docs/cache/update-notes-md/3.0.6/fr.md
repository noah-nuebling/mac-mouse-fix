Mac Mouse Fix **3.0.6** rend la fonctionnalité « Retour » et « Avancer » compatible avec plus d'applications.
Cette version corrige également plusieurs bugs et problèmes.

### Amélioration de la fonctionnalité « Retour » et « Avancer »

Les assignations des boutons de souris « Retour » et « Avancer » **fonctionnent maintenant dans plus d'applications**, notamment :

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed et autres éditeurs de code
- De nombreuses applications Apple intégrées telles qu'Aperçu, Notes, Réglages Système, App Store et Musique
- Adobe Acrobat
- Zotero
- Et plus encore !

L'implémentation s'inspire de l'excellente fonctionnalité « Universal Back and Forward » de [LinearMouse](https://github.com/linearmouse/linearmouse). Elle devrait prendre en charge toutes les applications que LinearMouse supporte. \
De plus, elle prend en charge certaines applications qui nécessitent normalement des raccourcis clavier pour revenir en arrière ou avancer, comme Réglages Système, App Store, Notes d'Apple et Adobe Acrobat. Mac Mouse Fix détectera désormais ces applications et simulera les raccourcis clavier appropriés.

Toutes les applications qui ont été [demandées dans un ticket GitHub](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) devraient maintenant être prises en charge ! (Merci pour vos retours !) \
Si tu trouves des applications qui ne fonctionnent pas encore, fais-le moi savoir via une [demande de fonctionnalité](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Correction du bug « Le défilement cesse de fonctionner par intermittence »

Certains utilisateurs ont rencontré un [problème](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) où **le défilement fluide cesse de fonctionner** de manière aléatoire.

Bien que je n'aie jamais pu reproduire ce problème, j'ai implémenté une correction potentielle :

L'application réessaiera maintenant plusieurs fois lorsque la configuration de la synchronisation d'affichage échoue. \
Si cela ne fonctionne toujours pas après plusieurs tentatives, l'application :

- Redémarrera le processus en arrière-plan « Mac Mouse Fix Helper », ce qui pourrait résoudre le problème
- Produira un rapport de crash, qui pourrait aider à diagnostiquer le bug

J'espère que le problème est maintenant résolu ! Sinon, fais-le moi savoir via un [rapport de bug](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) ou par [e-mail](http://redirect.macmousefix.com/?target=mailto-noah).



### Amélioration du comportement de la molette à défilement libre

Mac Mouse Fix **n'accélérera plus le défilement** pour toi lorsque tu laisses la molette tourner librement sur la souris MX Master. (Ou toute autre souris avec une molette à défilement libre.)

Bien que cette fonctionnalité d'« accélération du défilement » soit utile sur les molettes classiques, sur une molette à défilement libre, elle peut rendre les choses plus difficiles à contrôler.

**Remarque :** Mac Mouse Fix n'est actuellement pas entièrement compatible avec la plupart des souris Logitech, y compris la MX Master. Je prévois d'ajouter une prise en charge complète, mais cela prendra probablement du temps. En attendant, le meilleur pilote tiers avec prise en charge Logitech que je connaisse est [SteerMouse](https://plentycom.jp/en/steermouse/).





### Corrections de bugs

- Correction d'un problème où Mac Mouse Fix réactivait parfois des raccourcis clavier qui avaient été précédemment désactivés dans Réglages Système
- Correction d'un crash lors du clic sur « Activer la licence »
- Correction d'un crash lors du clic sur « Annuler » juste après avoir cliqué sur « Activer la licence » (Merci pour le signalement, Ali !)
- Correction de crashs lors de tentatives d'utilisation de Mac Mouse Fix sans écran connecté à ton Mac
- Correction d'une fuite mémoire et d'autres problèmes internes lors du changement d'onglets dans l'application

### Améliorations visuelles

- Correction d'un problème où l'onglet À propos était parfois trop haut, introduit dans la version [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Le texte de la notification « Les jours gratuits sont terminés » n'est plus coupé en chinois
- Correction d'un problème visuel sur l'ombre du champ « + » après l'enregistrement d'une entrée
- Correction d'un bug rare où le texte de substitution sur l'écran « Saisir votre clé de licence » apparaissait décentré
- Correction d'un problème où certains symboles affichés dans l'application avaient la mauvaise couleur après le passage entre les modes sombre/clair

### Autres améliorations

- Optimisation de certaines animations, comme l'animation de changement d'onglet
- Désactivation de la complétion de texte Touch Bar sur l'écran « Saisir votre clé de licence »
- Diverses petites améliorations internes

*Édité avec l'excellente assistance de Claude.*

---

Consulte également la version précédente [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).