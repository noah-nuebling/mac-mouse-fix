Découvrez aussi les **nouveautés** introduites dans [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0) !

---

Mac Mouse Fix **2.2.0** apporte diverses améliorations d'utilisation et corrections de bugs !

### Le remappage des touches de fonction exclusives à Apple est maintenant amélioré

La dernière mise à jour, 2.1.0, a introduit une nouvelle fonctionnalité permettant de remapper les boutons de votre souris vers n'importe quelle touche de votre clavier - même les touches de fonction uniquement présentes sur les claviers Apple. La version 2.2.0 apporte des améliorations supplémentaires à cette fonctionnalité :

- Vous pouvez maintenant maintenir Option (⌥) pour remapper vers des touches uniquement présentes sur les claviers Apple - même si vous n'avez pas de clavier Apple sous la main.
- L'apparence des symboles des touches de fonction a été améliorée, s'intégrant mieux avec le reste du texte.
- La possibilité de remapper vers Verr Maj a été désactivée. Elle ne fonctionnait pas comme prévu.

### Ajoutez / supprimez des Actions plus facilement

Certains utilisateurs avaient du mal à comprendre qu'il est possible d'ajouter et de supprimer des Actions du Tableau d'Actions. Pour rendre les choses plus compréhensibles, la version 2.2.0 propose les changements et nouvelles fonctionnalités suivants :

- Vous pouvez maintenant supprimer des Actions par clic droit.
  - Cela devrait rendre l'option de suppression des Actions plus facile à découvrir.
  - Le menu contextuel affiche un symbole du bouton '-'. Cela devrait attirer l'attention sur le _bouton_ '-', qui devrait ensuite attirer l'attention sur le bouton '+'. Cela devrait rendre l'option d'**ajout** d'Actions plus visible également.
- Vous pouvez maintenant ajouter des Actions au Tableau d'Actions en faisant un clic droit sur une ligne vide.
- Le bouton '-' n'est maintenant actif que lorsqu'une Action est sélectionnée. Cela devrait rendre plus clair que le bouton '-' supprime l'Action sélectionnée.
- La hauteur par défaut de la fenêtre a été augmentée pour qu'il y ait une ligne vide visible sur laquelle on peut faire un clic droit pour ajouter une Action.
- Les boutons '+' et '-' ont maintenant des info-bulles.

### Améliorations du Cliquer-Glisser

Le seuil d'activation du Cliquer-Glisser est passé de 5 pixels à 7 pixels. Cela rend plus difficile l'activation accidentelle du Cliquer-Glisser, tout en permettant aux utilisateurs de changer d'espace de travail avec des petits mouvements confortables.

### Autres changements d'interface

- L'apparence du Tableau d'Actions a été améliorée.
- Diverses autres améliorations de l'interface.

### Corrections de bugs

- Correction d'un problème où l'interface n'était pas grisée lors du démarrage de MMF alors qu'il était désactivé.
- Suppression de l'option cachée "Cliquer-Glisser du Bouton 3".
  - Lors de sa sélection, l'application plantait. J'ai créé cette option pour rendre Mac Mouse Fix plus compatible avec Blender. Mais dans sa forme actuelle, elle n'est pas très utile pour les utilisateurs de Blender car elle ne peut pas être combinée avec des modificateurs de clavier. Je prévois d'améliorer la compatibilité avec Blender dans une prochaine version.