Mac Mouse Fix **2.2.5** apporte des améliorations au mécanisme de mise à jour et est prêt pour macOS 15 Sequoia !

### Nouveau framework de mise à jour Sparkle

Mac Mouse Fix utilise le framework de mise à jour [Sparkle](https://sparkle-project.org/) pour offrir une excellente expérience de mise à jour.

Avec la version 2.2.5, Mac Mouse Fix passe de Sparkle 1.26.0 à la dernière version [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), qui inclut des correctifs de sécurité, des améliorations de localisation et plus encore.

### Mécanisme de mise à jour plus intelligent

Un nouveau mécanisme décide quelle mise à jour montrer à l'utilisateur. Le comportement a changé de la manière suivante :

1. Après avoir ignoré une mise à jour **majeure** (comme 2.2.5 -> 3.0.0), vous serez toujours notifié des nouvelles mises à jour **mineures** (comme 2.2.5 -> 2.2.6).
    - Cela vous permet de rester facilement sur Mac Mouse Fix 2 tout en recevant des mises à jour, comme discuté dans le problème GitHub [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Au lieu d'afficher la mise à jour vers la dernière version, Mac Mouse Fix vous montrera maintenant la mise à jour vers la première version de la dernière version majeure.
    - Exemple : Si vous utilisez MMF 2.2.5, et que MMF 3.4.5 est la dernière version, l'application vous montrera maintenant la première version de MMF 3 (3.0.0), au lieu de la dernière version (3.4.5). Ainsi, tous les utilisateurs de MMF 2.2.5 verront le journal des modifications de MMF 3.0.0 avant de passer à MMF 3.
    - Discussion :
        - La principale motivation est que, plus tôt cette année, de nombreux utilisateurs de MMF 2 ont mis à jour directement de MMF 2 vers MMF 3.0.1 ou 3.0.2. N'ayant jamais vu le journal des modifications de 3.0.0, ils ont manqué les informations sur les changements de prix entre MMF 2 et MMF 3 (MMF 3 n'étant plus 100% gratuit). Donc quand MMF 3 leur a soudainement demandé de payer pour continuer à utiliser l'application, certains étaient - compréhensiblement - un peu confus et contrariés.
        - Inconvénient : Si vous voulez simplement mettre à jour vers la dernière version, vous devrez maintenant parfois faire deux mises à jour. C'est légèrement inefficace, mais cela ne devrait prendre que quelques secondes. Et comme cela rend les changements entre les versions majeures beaucoup plus transparents, je pense que c'est un compromis raisonnable.

### Support de macOS 15 Sequoia

Mac Mouse Fix 2.2.5 fonctionnera parfaitement sur le nouveau macOS 15 Sequoia - tout comme la version 2.2.4.

---

Découvrez également la version précédente [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Si vous avez des difficultés à activer Mac Mouse Fix après la mise à jour, consultez le [Guide 'Activation de Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*