Découvrez aussi les **belles améliorations** introduites dans [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6) !


---

**3.0.0 Beta 7** apporte plusieurs petites améliorations et corrections de bugs.

Voici toutes les nouveautés :

**Améliorations**

- Ajout des **traductions en coréen**. Un grand merci à @jeongtae ! (Retrouvez-le sur [GitHub](https://github.com/jeongtae))
- Le **défilement** avec l'option 'Fluidité : Élevée' est **encore plus fluide**, en ne modifiant la vitesse que progressivement, au lieu d'avoir des sauts brusques dans la vitesse de défilement lorsque vous déplacez la molette. Cela devrait rendre le défilement un peu plus fluide et plus facile à suivre des yeux sans réduire la réactivité. Le défilement avec 'Fluidité : Élevée' utilise environ 30% de CPU en plus, sur mon ordinateur il est passé de 1,2% d'utilisation CPU en défilement continu à 1,6%. Le défilement reste donc très efficace et j'espère que cela ne fera pas de différence pour quiconque. Un grand merci à [MOS](https://mos.caldis.me/), qui a inspiré cette fonctionnalité et dont j'ai utilisé le 'Scroll Monitor' pour aider à l'implémenter.
- Mac Mouse Fix **gère maintenant les entrées de boutons de toutes sources**. Auparavant, Mac Mouse Fix ne gérait que les entrées des souris qu'il reconnaissait. Je pense que cela pourrait améliorer la compatibilité avec certaines souris dans des cas particuliers, comme lors de l'utilisation d'un Hackintosh, mais cela conduira aussi Mac Mouse Fix à détecter les entrées de boutons générées artificiellement par d'autres applications, ce qui pourrait poser des problèmes dans d'autres cas particuliers. Faites-moi savoir si cela vous pose des problèmes, et je les traiterai dans les futures mises à jour.
- Affinement de la sensation et du raffinement des gestes 'Cliquer et faire défiler' pour 'Bureau et Launchpad' et 'Cliquer et faire défiler' pour 'Se déplacer entre les Spaces'.
- Prise en compte de la densité d'information d'une langue lors du calcul du **temps d'affichage des notifications**. Auparavant, les notifications ne restaient visibles que très peu de temps dans les langues à haute densité d'information comme le chinois ou le coréen.
- Activation de **différents gestes** pour se déplacer entre les **Spaces**, ouvrir **Mission Control**, ou ouvrir **App Exposé**. Dans la Beta 6, j'avais fait en sorte que ces actions ne soient disponibles que via le geste 'Cliquer et faire glisser' - comme une expérience pour voir combien de personnes tenaient vraiment à pouvoir accéder à ces actions d'autres manières. Il semble que certains y tiennent, donc j'ai rendu à nouveau possible l'accès à ces actions via un simple 'Clic' d'un bouton ou via 'Cliquer et faire défiler'.
- Ajout de la possibilité de **Pivoter** via un geste **Cliquer et faire défiler**.
- **Amélioration** du fonctionnement de l'option **Simulation du trackpad** dans certains scénarios. Par exemple, lors du défilement horizontal pour supprimer un message dans Mail, la direction du déplacement du message est maintenant inversée, ce qui devrait sembler un peu plus naturel et cohérent pour la plupart des utilisateurs.
- Ajout d'une fonction pour **remapper** vers le **Clic principal** ou le **Clic secondaire**. J'ai implémenté cela car le bouton droit de ma souris préférée s'est cassé. Ces options sont masquées par défaut. Vous pouvez les voir en maintenant la touche Option enfoncée lors de la sélection d'une action.
  - Il manque actuellement les traductions en chinois et en coréen pour ces fonctionnalités, donc si vous souhaitez contribuer aux traductions, ce serait grandement apprécié !

**Corrections de bugs**

- Correction d'un bug où la **direction du 'Cliquer et faire glisser'** pour 'Mission Control & Spaces' était **inversée** pour les personnes qui n'ont jamais basculé l'option 'Défilement naturel' dans les Réglages Système. Maintenant, la direction des gestes 'Cliquer et faire glisser' dans Mac Mouse Fix devrait toujours correspondre à la direction des gestes sur votre Trackpad ou Magic Mouse. Si vous souhaitez une option séparée pour inverser la direction 'Cliquer et faire glisser', au lieu de suivre les Réglages Système, faites-le moi savoir.
- Correction d'un bug où les **jours gratuits** **s'incrémentaient trop rapidement** pour certains utilisateurs. Si vous avez été affecté par ce problème, faites-le moi savoir et je verrai ce que je peux faire.
- Correction d'un problème sous macOS Sonoma où la barre d'onglets ne s'affichait pas correctement.
- Correction des saccades lors de l'utilisation de la vitesse de défilement 'macOS' avec 'Cliquer et faire défiler' pour ouvrir Launchpad.
- Correction d'un crash où l'application 'Mac Mouse Fix Helper' (qui s'exécute en arrière-plan lorsque Mac Mouse Fix est activé) plantait parfois lors de l'enregistrement d'un raccourci clavier.
- Correction d'un bug où Mac Mouse Fix plantait en essayant de détecter les événements artificiels générés par [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma)
- Correction d'un problème où le nom de certaines souris affiché dans la boîte de dialogue 'Restaurer les valeurs par défaut...' contenait deux fois le fabricant.
- Réduction de la probabilité que 'Cliquer et faire glisser' pour 'Mission Control & Spaces' se bloque lorsque l'ordinateur est lent.
- Correction de l'utilisation de 'Force Touch' dans les chaînes de l'interface utilisateur où il devrait être 'Force click'.
- Correction d'un bug qui se produisait pour certaines configurations, où l'ouverture de Launchpad ou l'affichage du Bureau via 'Cliquer et faire défiler' ne fonctionnait pas si vous relâchiez le bouton pendant que l'animation de transition était encore en cours.


**Plus**

- Plusieurs améliorations sous le capot, améliorations de la stabilité, nettoyage sous le capot, et plus encore.

## Comment vous pouvez aider

Vous pouvez aider en partageant vos **idées**, **problèmes** et **retours** !

Le meilleur endroit pour partager vos **idées** et **problèmes** est l'[Assistant de feedback](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Le meilleur endroit pour donner des retours **rapides** non structurés est la [Discussion de feedback](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Vous pouvez également accéder à ces endroits depuis l'application dans l'onglet '**ⓘ À propos**'.

**Merci** d'aider à améliorer Mac Mouse Fix ! 😎:)