Mac Mouse Fix **3.0.5** corrige plusieurs bugs, améliore les performances et apporte un peu de finition à l'application. \
Elle est également compatible avec macOS 26 Tahoe.

### Amélioration de la simulation du défilement au trackpad

- Le système de défilement peut maintenant simuler un tapotement à deux doigts sur le trackpad pour faire arrêter le défilement dans les applications.
    - Cela corrige un problème lors de l'exécution d'applications iPhone ou iPad, où le défilement continuait souvent après que l'utilisateur ait choisi de s'arrêter.
- Correction de la simulation incohérente du retrait des doigts du trackpad.
    - Cela pouvait causer un comportement sous-optimal dans certaines situations.



### Compatibilité avec macOS 26 Tahoe

Lors de l'exécution de la version bêta de macOS 26 Tahoe, l'application est maintenant utilisable et la plupart de l'interface fonctionne correctement.



### Amélioration des performances

Amélioration des performances du geste Cliquer et glisser pour « Défiler et naviguer ». \
Dans mes tests, l'utilisation du processeur a été réduite d'environ 50 % !

**Contexte**

Pendant le geste « Défiler et naviguer », Mac Mouse Fix dessine un faux curseur de souris dans une fenêtre transparente, tout en verrouillant le vrai curseur de souris en place. Cela garantit que tu peux continuer à faire défiler l'élément d'interface sur lequel tu as commencé à défiler, peu importe la distance à laquelle tu déplaces ta souris.

L'amélioration des performances a été obtenue en désactivant la gestion par défaut des événements macOS sur cette fenêtre transparente, qui n'était de toute façon pas utilisée.





### Corrections de bugs

- Ignore maintenant les événements de défilement des tablettes graphiques Wacom.
    - Auparavant, Mac Mouse Fix causait un défilement erratique sur les tablettes Wacom, comme signalé par @frenchie1980 dans le problème GitHub [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Merci !)
    
- Correction d'un bug où le code Swift Concurrency, qui a été introduit dans le cadre du nouveau système de licence dans Mac Mouse Fix 3.0.4, ne s'exécutait pas sur le bon thread.
    - Cela causait des plantages sur macOS Tahoe, et cela a probablement aussi causé d'autres bugs sporadiques liés aux licences.
- Amélioration de la robustesse du code qui décode les licences hors ligne.
    - Cela contourne un problème dans les API d'Apple qui faisait que la validation des licences hors ligne échouait toujours sur mon Mac Mini Intel. Je suppose que cela se produisait sur tous les Mac Intel, et que c'était la raison pour laquelle le bug « Jours gratuits terminés » (qui avait déjà été traité dans la version 3.0.4) se produisait encore pour certaines personnes, comme signalé par @toni20k5267 dans le problème GitHub [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Merci !)
        - Si tu as rencontré le bug « Jours gratuits terminés », je suis désolé ! Tu peux obtenir un remboursement [ici](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Améliorations de l'expérience utilisateur

- Désactivation des dialogues qui fournissaient des solutions étape par étape pour les bugs macOS qui empêchaient les utilisateurs d'activer Mac Mouse Fix.
    - Ces problèmes ne se produisaient que sur macOS 13 Ventura et 14 Sonoma. Maintenant, ces dialogues n'apparaissent que sur les versions de macOS où ils sont pertinents.
    - Les dialogues sont également un peu plus difficiles à déclencher – auparavant, ils apparaissaient parfois dans des situations où ils n'étaient pas très utiles.
    
- Ajout d'un lien « Activer la licence » directement sur la notification « Jours gratuits terminés ».
    - Cela rend l'activation d'une licence Mac Mouse Fix encore plus simple !

### Améliorations visuelles

- Légère amélioration de l'apparence de la fenêtre « Mise à jour logicielle ». Elle s'intègre maintenant mieux avec macOS 26 Tahoe.
    - Cela a été fait en personnalisant l'apparence par défaut du framework « Sparkle 1.27.3 » que Mac Mouse Fix utilise pour gérer les mises à jour.
- Correction d'un problème où le texte en bas de l'onglet À propos était parfois coupé en chinois, en rendant la fenêtre légèrement plus large.
- Correction du texte en bas de l'onglet À propos qui était légèrement décentré.
- Correction d'un bug qui faisait que l'espace sous l'option « Raccourci clavier... » dans l'onglet Boutons était trop petit.

### Modifications internes

- Suppression de la dépendance au framework « SnapKit ».
    - Cela réduit légèrement la taille de l'application de 19,8 à 19,5 Mo.
- Diverses autres petites améliorations dans le code.

*Édité avec l'excellente assistance de Claude.*

---

Consulte également la version précédente [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).