Découvrez aussi les **nouveautés intéressantes** introduites dans [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4) !

---

**3.0.0 Beta 5** rétablit la **compatibilité** avec certaines **souris** sous macOS 13 Ventura et **corrige le défilement** dans de nombreuses applications.
Elle comprend également plusieurs autres petites corrections et améliorations de la qualité de vie.

Voici **toutes les nouveautés** :

### Souris

- Correction du défilement dans Terminal et d'autres applications ! Voir le problème GitHub [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Correction de l'incompatibilité avec certaines souris sous macOS 13 Ventura en abandonnant l'utilisation d'APIs Apple peu fiables au profit de solutions de bas niveau. J'espère que cela n'introduira pas de nouveaux problèmes - faites-moi savoir si c'est le cas ! Merci particulièrement à Maria et à l'utilisateur GitHub [samiulhsnt](https://github.com/samiulhsnt) pour leur aide ! Voir le problème GitHub [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) pour plus d'informations.
- N'utilisera plus de CPU lors du clic sur les boutons 1 ou 2 de la souris. Légère réduction de l'utilisation du CPU lors du clic sur d'autres boutons.
    - Ceci est une "Version de débogage" donc l'utilisation du CPU peut être environ 10 fois plus élevée lors du clic sur les boutons dans cette version bêta par rapport à la version finale
- La simulation du défilement du trackpad utilisée pour les fonctionnalités "Défilement fluide" et "Défilement & Navigation" de Mac Mouse Fix est maintenant encore plus précise. Cela pourrait conduire à un meilleur comportement dans certaines situations.

### Interface utilisateur

- Correction automatique des problèmes d'accès à l'accessibilité après la mise à jour depuis une ancienne version de Mac Mouse Fix. Adoption des changements décrits dans les [notes de version 2.2.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Ajout d'un bouton "Annuler" à l'écran "Accorder l'accès à l'accessibilité"
- Correction d'un problème où la configuration de Mac Mouse Fix ne fonctionnait pas correctement après l'installation d'une nouvelle version, car la nouvelle version se connectait à l'ancienne version de "Mac Mouse Fix Helper". Désormais, Mac Mouse Fix ne se connectera plus à l'ancien "Mac Mouse Fix Helper" et désactivera automatiquement l'ancienne version le cas échéant.
- Instructions données à l'utilisateur pour résoudre un problème où Mac Mouse Fix ne peut pas être activé correctement en raison de la présence d'une autre version sur le système. Ce problème ne survient que sous macOS Ventura.
- Amélioration du comportement et des animations sur l'écran "Accorder l'accès à l'accessibilité"
- Mac Mouse Fix sera mis au premier plan lors de son activation. Cela améliore les interactions avec l'interface dans certaines situations, comme lorsque vous activez Mac Mouse Fix après qu'il ait été désactivé dans Réglages Système > Général > Ouverture.
- Amélioration des textes de l'interface sur l'écran "Accorder l'accès à l'accessibilité"
- Amélioration des textes de l'interface qui s'affichent lors de la tentative d'activation de Mac Mouse Fix alors qu'il est désactivé dans les Réglages Système
- Correction d'un texte en allemand

### Sous le capot

- Le numéro de build de "Mac Mouse Fix" et du "Mac Mouse Fix Helper" intégré sont maintenant synchronisés. Cela permet d'éviter que "Mac Mouse Fix" ne se connecte accidentellement à d'anciennes versions de "Mac Mouse Fix Helper".
- Correction d'un problème où certaines données concernant votre licence et la période d'essai s'affichaient parfois incorrectement lors du premier démarrage de l'application en supprimant les données en cache de la configuration initiale
- Nombreux nettoyages de la structure du projet et du code source
- Amélioration des messages de débogage

---

### Comment vous pouvez aider

Vous pouvez aider en partageant vos **idées**, **problèmes** et **retours** !

Le meilleur endroit pour partager vos **idées** et **problèmes** est l'[Assistant de feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Le meilleur endroit pour donner des retours **rapides** non structurés est la [Discussion de feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Vous pouvez également accéder à ces endroits depuis l'application dans l'onglet "**ⓘ À propos**".

**Merci** d'aider à améliorer Mac Mouse Fix ! 💙💛❤️