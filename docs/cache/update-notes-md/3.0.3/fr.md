**ℹ️ Note aux utilisateurs de Mac Mouse Fix 2**

Avec l'introduction de Mac Mouse Fix 3, le modèle de tarification de l'application a changé :

- **Mac Mouse Fix 2**\
Reste 100% gratuit, et je prévois de continuer à le supporter.\
**Ignorez cette mise à jour** pour continuer à utiliser Mac Mouse Fix 2. Téléchargez la dernière version de Mac Mouse Fix 2 [ici](https://redirect.macmousefix.com/?target=mmf2-latest).
- **Mac Mouse Fix 3**\
Gratuit pendant 30 jours, coûte quelques euros pour l'acquérir.\
**Mettez à jour maintenant** pour obtenir Mac Mouse Fix 3 !

Vous pouvez en savoir plus sur la tarification et les fonctionnalités de Mac Mouse Fix 3 sur le [nouveau site web](https://macmousefix.com/).

Merci d'utiliser Mac Mouse Fix ! :)

---

**ℹ️ Note aux acheteurs de Mac Mouse Fix 3**

Si vous avez accidentellement mis à jour vers Mac Mouse Fix 3 sans savoir qu'il n'était plus gratuit, je vous propose un [remboursement](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

La dernière version de Mac Mouse Fix 2 reste **entièrement gratuite**, et vous pouvez la télécharger [ici](https://redirect.macmousefix.com/?target=mmf2-latest).

Je suis désolé pour le désagrément, et j'espère que cette solution convient à tout le monde !

---

Mac Mouse Fix **3.0.3** est prêt pour macOS 15 Sequoia. Il corrige également quelques problèmes de stabilité et apporte plusieurs petites améliorations.

### Support de macOS 15 Sequoia

L'application fonctionne maintenant correctement sous macOS 15 Sequoia !

- La plupart des animations de l'interface étaient défectueuses sous macOS 15 Sequoia. Maintenant tout fonctionne correctement !
- Le code source peut maintenant être compilé sous macOS 15 Sequoia. Auparavant, il y avait des problèmes avec le compilateur Swift empêchant la compilation de l'application.

### Résolution des crashs lors du défilement

Depuis Mac Mouse Fix 3.0.2, il y a eu [plusieurs signalements](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) indiquant que Mac Mouse Fix se désactivait et se réactivait périodiquement pendant le défilement. Cela était dû à des crashs de l'application d'arrière-plan 'Mac Mouse Fix Helper'. Cette mise à jour tente de corriger ces crashs avec les modifications suivantes :

- Le mécanisme de défilement essaiera de récupérer et de continuer à fonctionner au lieu de planter lorsqu'il rencontre le cas particulier qui semble avoir conduit à ces crashs.
- J'ai modifié la façon dont les états inattendus sont gérés dans l'application de manière plus générale : Au lieu de toujours planter immédiatement, l'application essaiera maintenant de récupérer des états inattendus dans de nombreux cas.

    - Ce changement contribue aux corrections des crashs de défilement décrits ci-dessus. Il pourrait également prévenir d'autres crashs.

Note : Je n'ai jamais pu reproduire ces crashs sur ma machine, et je ne suis toujours pas sûr de ce qui les a causés, mais d'après les signalements reçus, cette mise à jour devrait empêcher tout crash. Si vous rencontrez encore des crashs pendant le défilement ou si vous avez rencontré des crashs sous la version 3.0.2, il serait précieux que vous partagiez votre expérience et vos données de diagnostic dans l'Issue GitHub [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Cela m'aiderait à comprendre le problème et à améliorer Mac Mouse Fix. Merci !

### Résolution des saccades lors du défilement

Dans la version 3.0.2, j'ai modifié la façon dont Mac Mouse Fix envoie les événements de défilement au système dans le but de réduire les saccades probablement causées par des problèmes avec les API VSync d'Apple.

Cependant, après des tests plus approfondis et des retours d'utilisateurs, il semble que le nouveau mécanisme de la version 3.0.2 rende le défilement plus fluide dans certains scénarios mais plus saccadé dans d'autres. En particulier dans Firefox, il semblait être nettement moins bon.\
Dans l'ensemble, il n'était pas clair que le nouveau mécanisme améliorait réellement les saccades de défilement de manière générale. De plus, il a peut-être contribué aux crashs de défilement décrits ci-dessus.

C'est pourquoi j'ai désactivé le nouveau mécanisme et rétabli le mécanisme VSync pour les événements de défilement tel qu'il était dans Mac Mouse Fix 3.0.0 et 3.0.1.

Voir l'Issue GitHub [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) pour plus d'informations.

### Remboursement

Je suis désolé pour les problèmes liés aux changements de défilement dans les versions 3.0.1 et 3.0.2. J'ai largement sous-estimé les problèmes qui en découleraient, et j'ai été lent à résoudre ces problèmes. Je ferai de mon mieux pour tirer les leçons de cette expérience et être plus prudent avec de tels changements à l'avenir. Je souhaite également proposer un remboursement à toute personne affectée. Cliquez simplement [ici](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) si vous êtes intéressé.

### Mécanisme de mise à jour plus intelligent

Ces changements ont été repris de Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) et [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consultez leurs notes de version pour en savoir plus sur les détails. Voici un résumé :

- Il y a un nouveau mécanisme plus intelligent qui décide quelle mise à jour montrer à l'utilisateur.
- Passage du framework de mise à jour Sparkle 1.26.0 à la dernière version Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- La fenêtre que l'application affiche pour vous informer qu'une nouvelle version de Mac Mouse Fix est disponible prend maintenant en charge JavaScript, ce qui permet un meilleur formatage des notes de mise à jour.

### Autres améliorations et corrections de bugs

- Correction d'un problème où le prix de l'application et les informations connexes s'affichaient incorrectement dans l'onglet 'À propos' dans certains cas.
- Correction d'un problème où le mécanisme de synchronisation du défilement fluide avec le taux de rafraîchissement de l'écran ne fonctionnait pas correctement lors de l'utilisation de plusieurs écrans.
- Nombreux nettoyages et améliorations mineures sous le capot.

---

Consultez également la version précédente [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).