Mac Mouse Fix **3.0.3** est prêt pour macOS 15 Sequoia. Il corrige également certains problèmes de stabilité et apporte plusieurs petites améliorations.

### Support de macOS 15 Sequoia

L'application fonctionne maintenant correctement sous macOS 15 Sequoia !

- La plupart des animations de l'interface utilisateur étaient cassées sous macOS 15 Sequoia. Maintenant tout fonctionne à nouveau correctement !
- Le code source est maintenant compilable sous macOS 15 Sequoia. Auparavant, il y avait des problèmes avec le compilateur Swift empêchant la compilation de l'application.

### Résolution des plantages lors du défilement

Depuis Mac Mouse Fix 3.0.2, il y a eu [plusieurs signalements](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) de Mac Mouse Fix se désactivant et se réactivant périodiquement pendant le défilement. Cela était causé par des plantages de l'application en arrière-plan 'Mac Mouse Fix Helper'. Cette mise à jour tente de corriger ces plantages, avec les changements suivants :

- Le mécanisme de défilement tentera de récupérer et de continuer à fonctionner au lieu de planter, lorsqu'il rencontre le cas limite qui semble avoir conduit à ces plantages.
- J'ai modifié la façon dont les états inattendus sont gérés dans l'application de manière plus générale : Au lieu de toujours planter immédiatement, l'application tentera maintenant de récupérer des états inattendus dans de nombreux cas.
    
    - Ce changement contribue aux corrections des plantages de défilement décrits ci-dessus. Il pourrait également prévenir d'autres plantages.
  
Note : Je n'ai jamais pu reproduire ces plantages sur ma machine, et je ne suis toujours pas sûr de ce qui les a causés, mais d'après les signalements que j'ai reçus, cette mise à jour devrait prévenir tout plantage. Si tu rencontres toujours des plantages pendant le défilement ou si tu *as* rencontré des plantages sous 3.0.2, il serait précieux que tu partages ton expérience et tes données de diagnostic dans le GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Cela m'aiderait à comprendre le problème et à améliorer Mac Mouse Fix. Merci !

### Résolution des saccades lors du défilement

Dans la version 3.0.2, j'ai modifié la façon dont Mac Mouse Fix envoie les événements de défilement au système dans une tentative de réduire les saccades de défilement probablement causées par des problèmes avec les API VSync d'Apple.

Cependant, après des tests plus approfondis et des retours, il semble que le nouveau mécanisme dans la version 3.0.2 rende le défilement plus fluide dans certains scénarios mais plus saccadé dans d'autres. Particulièrement dans Firefox, il semblait être nettement pire. \
Dans l'ensemble, il n'était pas clair que le nouveau mécanisme améliorait réellement les saccades de défilement de manière générale. De plus, il pourrait avoir contribué aux plantages de défilement décrits ci-dessus.

C'est pourquoi j'ai désactivé le nouveau mécanisme et rétabli le mécanisme VSync pour les événements de défilement tel qu'il était dans Mac Mouse Fix 3.0.0 et 3.0.1.

Voir le GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) pour plus d'informations.

### Remboursement

Je suis désolé pour les problèmes liés aux changements de défilement dans les versions 3.0.1 et 3.0.2. J'ai largement sous-estimé les problèmes qui en découleraient, et j'ai été lent à résoudre ces problèmes. Je ferai de mon mieux pour apprendre de cette expérience et être plus prudent avec de tels changements à l'avenir. J'aimerais également offrir un remboursement à toute personne affectée. Clique simplement [ici](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) si tu es intéressé.

### Mécanisme de mise à jour plus intelligent

Ces changements ont été repris de Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) et [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Consulte leurs notes de version pour en savoir plus sur les détails. Voici un résumé :

- Il y a un nouveau mécanisme plus intelligent qui décide quelle mise à jour montrer à l'utilisateur.
- Passage du framework de mise à jour Sparkle 1.26.0 à la dernière version Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- La fenêtre que l'application affiche pour t'informer qu'une nouvelle version de Mac Mouse Fix est disponible prend maintenant en charge JavaScript, ce qui permet un meilleur formatage des notes de mise à jour.

### Autres améliorations et corrections de bugs

- Correction d'un problème où le prix de l'application et les informations associées étaient affichés incorrectement dans l'onglet 'À propos' dans certains cas.
- Correction d'un problème où le mécanisme de synchronisation du défilement fluide avec le taux de rafraîchissement de l'écran ne fonctionnait pas correctement lors de l'utilisation de plusieurs écrans.
- De nombreux nettoyages et améliorations mineurs en coulisses.

---

Consulte également la version précédente [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).