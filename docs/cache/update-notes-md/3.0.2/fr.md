Mac Mouse Fix **3.0.2** apporte plusieurs améliorations, notamment un **défilement plus fluide**, des traductions améliorées, et plus encore !

### Défilement

- Vous pouvez maintenant arrêter les animations de défilement en faisant défiler d'un cran dans la direction opposée. Cela vous permet de **'lancer'** et **'rattraper la page'** en utilisant 'Fluidité : Élevée', comme avec un Trackpad.
- Mac Mouse Fix envoie désormais les événements de défilement plus tôt dans le cycle de rafraîchissement de l'écran, donnant aux applications plus de temps pour traiter les événements et afficher le défilement de manière fluide. Cela **améliore le nombre d'images par seconde**, particulièrement sur les sites web complexes comme YouTube.com.
- Amélioration de la réactivité du paramètre 'Fluidité : Élevée', rendant le défilement plus facile à contrôler.
- Amélioration du mécanisme introduit dans la version 3.0.1 où la vitesse d'animation s'accélère lorsque vous tournez la molette plus rapidement en utilisant 'Fluidité : Normale'. Dans la version 3.0.2, l'accélération de l'animation devrait apparaître plus cohérente et prévisible, la rendant plus agréable visuellement tout en offrant un excellent contrôle.
- Correction d'un problème où la vitesse de défilement était trop lente, particulièrement lors de l'utilisation de l'option 'Précision'. Ce problème avait été introduit dans la version 3.0.1. Merci à @V-Coba d'avoir attiré l'attention sur ce point dans [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- Amélioration du comportement dans le navigateur Arc lors de l'utilisation de 'Cliquer et Défiler' pour 'Zoomer ou Dézoomer'.

### Localisation

- Mise à jour des traductions 🇻🇳 vietnamiennes. Merci à @nghlt !
- Amélioration de certaines traductions 🇩🇪 allemandes.
- Le texte dans Mac Mouse Fix qui n'a pas de traduction pour la langue actuelle affichera désormais une valeur par défaut au lieu d'être simplement vide. Cela devrait rendre la navigation dans l'application moins déroutante lorsqu'il manque des traductions.

### Autres

- Mac Mouse Fix affichera désormais une notification avec un lien vers [ce guide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) pour les utilisateurs qui pourraient rencontrer un bug dans macOS 13 Ventura et versions ultérieures qui peut empêcher l'activation de Mac Mouse Fix.
- Modification des paramètres par défaut pour les souris à 3 boutons. Les paramètres par défaut n'incluent plus d'action 'Cliquer et Défiler' pour le bouton de la molette, car c'est assez difficile à réaliser. À la place, les paramètres par défaut incluent maintenant une action 'Maintenir' et une action 'Double-clic'.
- Ajout d'une infobulle à l'icône Mac Mouse Fix dans l'onglet À propos. Elle indique comment révéler le fichier de configuration de Mac Mouse Fix dans le Finder.
- Nombreux nettoyages et améliorations sous le capot.

---

Découvrez également la version précédente [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).