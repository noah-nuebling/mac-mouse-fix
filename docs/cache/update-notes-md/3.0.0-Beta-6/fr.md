Découvrez aussi les **changements intéressants** introduits dans [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5) !


---

**3.0.0 Beta 6** apporte des optimisations profondes et des améliorations, une refonte des paramètres de défilement, des traductions en chinois, et plus encore !

Voici toutes les nouveautés :

## 1. Optimisations profondes

Pour cette Beta, j'ai beaucoup travaillé pour obtenir les meilleures performances possibles de Mac Mouse Fix. Et je suis heureux d'annoncer que, lorsque vous cliquez sur un bouton de la souris dans la Beta 6, c'est **2 fois** plus rapide par rapport à la beta précédente ! Et le défilement est même **4 fois** plus rapide !

Avec la Beta 6, MMF désactivera intelligemment certaines de ses fonctionnalités pour économiser au maximum votre CPU et votre batterie.

Par exemple, si vous utilisez actuellement une souris à 3 boutons mais que vous n'avez configuré des actions que pour des boutons non présents sur votre souris comme les boutons 4 et 5, Mac Mouse Fix arrêtera complètement d'écouter les entrées des boutons de votre souris. Cela signifie 0% d'utilisation du CPU lorsque vous cliquez sur un bouton de votre souris ! Ou lorsque les paramètres de défilement dans MMF correspondent au système, Mac Mouse Fix arrêtera complètement d'écouter les entrées de votre molette de défilement. Cela signifie 0% d'utilisation du CPU lorsque vous faites défiler ! Mais si vous configurez la fonction Command (⌘)-Défilement pour zoomer, Mac Mouse Fix commencera à écouter les entrées de votre molette de défilement - mais uniquement lorsque vous maintenez la touche Command (⌘) enfoncée. Et ainsi de suite.
C'est donc vraiment intelligent et n'utilisera le CPU que lorsque c'est nécessaire !

Cela signifie que MMF n'est pas seulement le pilote de souris le plus puissant, facile à utiliser et raffiné pour Mac, c'est aussi l'un des plus optimisés et efficaces, si ce n'est le plus !

## 2. Taille de l'application réduite

À 16 Mo, la Beta 6 est environ 2 fois plus petite que la Beta 5 !

C'est un effet secondaire de l'abandon du support des anciennes versions de macOS.

## 3. Abandon du support des anciennes versions de macOS

J'ai essayé de faire fonctionner correctement MMF 3 sur les versions de macOS antérieures à macOS 11 Big Sur. Mais la quantité de travail nécessaire pour obtenir un résultat raffiné s'est avérée écrasante, j'ai donc dû abandonner.

À l'avenir, la version officiellement supportée la plus ancienne sera macOS 11 Big Sur.

L'application s'ouvrira toujours sur les versions plus anciennes mais il y aura des problèmes visuels et peut-être d'autres problèmes. L'application ne s'ouvrira plus sur les versions de macOS antérieures à 10.14.4. C'est ce qui nous permet de réduire la taille de l'application par 2, car 10.14.4 est la première version de macOS à intégrer les bibliothèques Swift modernes (voir "Swift ABI Stability"), ce qui signifie que ces bibliothèques Swift n'ont plus besoin d'être incluses dans l'application.

## 4. Améliorations du défilement

La Beta 6 comprend de nombreuses améliorations de la configuration et de l'interface utilisateur des nouveaux systèmes de défilement introduits dans MMF 3.

### Interface utilisateur

- Grandement simplifié et raccourci le texte de l'interface utilisateur dans l'onglet Défilement. La plupart des mentions du mot "Défilement" ont été supprimées car elles sont implicites dans le contexte.
- Remanié les paramètres de fluidité du défilement pour les rendre plus clairs et permettre des options supplémentaires. Vous pouvez maintenant choisir entre une "Fluidité" "Désactivée", "Normale" ou "Élevée", remplaçant l'ancien interrupteur "avec Inertie". Je pense que c'est beaucoup plus clair et cela a libéré de l'espace dans l'interface pour la nouvelle option "Simulation du trackpad".
- Désactiver la nouvelle option "Simulation du trackpad" désactive l'effet élastique pendant le défilement, empêche également le défilement entre les pages dans Safari et d'autres applications, et plus encore. Beaucoup de gens ont été gênés par cela, en particulier ceux qui ont des molettes de défilement à rotation libre comme sur certaines souris Logitech comme la MX Master, mais d'autres l'apprécient, j'ai donc décidé d'en faire une option. J'espère que la présentation de la fonctionnalité est claire. Si vous avez des suggestions à ce sujet, faites-le moi savoir.
- Changé l'option "Direction de défilement naturelle" en "Inverser la direction de défilement". Cela signifie que le paramètre inverse maintenant la direction de défilement du système et n'est plus indépendant de la direction de défilement du système. Bien que cela soit sans doute une expérience utilisateur légèrement moins bonne, cette nouvelle façon de faire permet de mettre en œuvre certaines optimisations et rend plus transparent pour l'utilisateur comment désactiver complètement Mac Mouse Fix pour le défilement.
- Amélioré la façon dont les paramètres de défilement interagissent avec le défilement modifié dans de nombreux cas limites. Par exemple, l'option "Précision" ne s'appliquera plus à l'action "Cliquer et faire défiler" pour "Bureau & Launchpad" car c'est un obstacle ici au lieu d'être utile.
- Amélioré la vitesse de défilement lors de l'utilisation de "Cliquer et faire défiler" pour "Bureau & Launchpad" ou "Zoom avant ou arrière" et d'autres fonctionnalités.
- Supprimé le lien non fonctionnel vers les paramètres de vitesse de défilement du système dans l'onglet défilement qui était présent sur les versions de macOS antérieures à macOS 13.0 Ventura. Je n'ai pas trouvé de moyen de faire fonctionner le lien et ce n'est pas terriblement important.

### Sensation de défilement

- Amélioré la courbe d'animation pour la "Fluidité normale" (anciennement accessible en désactivant "avec Inertie"). Cela rend les choses plus fluides et réactives.
- Amélioré la sensation de tous les paramètres de vitesse de défilement. Les vitesses "Moyenne" et "Rapide" sont plus rapides. Il y a plus de séparation entre les vitesses "Basse", "Moyenne" et "Élevée". L'accélération lorsque vous déplacez la molette plus rapidement semble plus naturelle et confortable lors de l'utilisation de l'option "Précision".
- La façon dont la vitesse de défilement augmente lorsque vous continuez à faire défiler dans une direction semblera plus naturelle et progressive. J'utilise de nouvelles courbes mathématiques pour modéliser l'accélération. L'augmentation de la vitesse sera également plus difficile à déclencher accidentellement.
- Ne plus augmenter la vitesse de défilement lorsque vous continuez à faire défiler dans une direction en utilisant la vitesse de défilement "macOS".
- Restreint le temps d'animation de défilement à un maximum. Si l'animation de défilement devait naturellement prendre plus de temps, elle sera accélérée pour rester en dessous du temps maximum. Ainsi, le défilement jusqu'au bord de la page avec une molette à rotation libre ne fera pas disparaître le contenu de la page aussi longtemps. Cela ne devrait pas affecter le défilement normal avec une molette sans rotation libre.
- Amélioré certaines interactions autour de l'effet élastique lors du défilement jusqu'au bord d'une page dans Safari et d'autres applications.
- Corrigé un problème où "Cliquer et faire défiler" et d'autres fonctionnalités liées au défilement ne fonctionnaient pas correctement après une mise à niveau depuis une très ancienne version du panneau de préférences de Mac Mouse Fix.
- Corrigé un problème où les défilements d'un pixel étaient envoyés avec un délai lors de l'utilisation de la vitesse de défilement "macOS" avec le défilement fluide.
- Corrigé un bug où le défilement était toujours très rapide après avoir relâché le modificateur de défilement rapide. Autres améliorations concernant la façon dont la vitesse de défilement est reportée des balayages de défilement précédents.
- Amélioré la façon dont la vitesse de défilement augmente avec les tailles d'écran plus grandes.

## 5. Notarisation

À partir de la version 3.0.0 Beta 6, Mac Mouse Fix sera "Notarisé". Cela signifie plus de messages concernant Mac Mouse Fix comme étant potentiellement un "Logiciel malveillant" lors de la première ouverture de l'application.

La notarisation de votre application coûte 100 $ par an. J'étais toujours contre cela, car cela semblait hostile envers les logiciels gratuits et open source comme Mac Mouse Fix, et cela semblait aussi être une étape dangereuse vers le contrôle et le verrouillage du Mac par Apple comme ils le font pour iOS. Mais l'absence de notarisation a conduit à des problèmes assez graves, y compris [plusieurs situations](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) où personne ne pouvait utiliser l'application jusqu'à ce que je publie une nouvelle version. Comme Mac Mouse Fix sera monétisé maintenant, j'ai pensé qu'il était enfin approprié de notariser l'application pour une expérience utilisateur plus facile et plus stable.

## 6. Traductions chinoises

Mac Mouse Fix est maintenant disponible en chinois !
Plus précisément, il est disponible en :

- Chinois traditionnel
- Chinois simplifié
- Chinois (Hong Kong)

Un grand merci à @groverlynn pour avoir fourni toutes ces traductions ainsi que pour les avoir mises à jour tout au long des betas et pour avoir communiqué avec moi. Voir sa pull request ici : https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Tout le reste

Outre les changements listés ci-dessus, la Beta 6 comprend également de nombreuses petites améliorations.

- Supprimé plusieurs options des actions "Clic", "Clic et maintien" et "Clic et défilement" car je pensais qu'elles étaient redondantes puisque la même fonctionnalité peut être obtenue autrement et que cela simplifie beaucoup les menus. Je ramènerai ces options si les gens se plaignent. Donc si ces options vous manquent - n'hésitez pas à vous plaindre.
- La direction du Clic et glisser correspondra maintenant à la direction du balayage du trackpad même lorsque "Défilement naturel" est désactivé dans Réglages Système > Trackpad. Auparavant, Clic et glisser se comportait toujours comme un balayage sur le trackpad avec "Défilement naturel" activé.
- Corrigé un problème où les curseurs disparaissaient puis réapparaissaient ailleurs lors de l'utilisation d'une action "Clic et glisser" pendant un enregistrement d'écran ou lors de l'utilisation du logiciel DisplayLink.
- Corrigé le centrage du "+" dans le champ "+" de l'onglet Boutons
- Plusieurs améliorations visuelles de l'onglet Boutons. La palette de couleurs du champ "+" et du tableau des actions a été retravaillée pour apparaître correctement lors de l'utilisation de l'option "Autoriser la teinte du fond d'écran dans les fenêtres" de macOS. Les bordures du tableau des actions ont maintenant une couleur transparente qui semble plus dynamique et s'adapte à son environnement.
- Fait en sorte que lorsque vous ajoutez beaucoup d'actions au tableau des actions et que la fenêtre Mac Mouse Fix grandit, elle grandira exactement à la taille de l'écran (ou de l'écran moins le Dock si vous n'avez pas activé le masquage automatique du Dock) puis s'arrêtera. Lorsque vous ajoutez encore plus d'actions, le tableau des actions commencera à défiler.
- Cette Beta prend maintenant en charge un nouveau système de paiement où vous pouvez acheter une licence en dollars américains comme annoncé. Auparavant, vous ne pouviez acheter une licence qu'en euros. Les anciennes licences en euros seront bien sûr toujours prises en charge.
- Corrigé un problème où le défilement avec élan n'était parfois pas lancé lors de l'utilisation de la fonction "Défilement & Navigation".
- Lorsque la fenêtre Mac Mouse Fix se redimensionne pendant un changement d'onglet, elle se repositionnera maintenant pour ne pas chevaucher le Dock
- Corrigé le scintillement sur certains éléments de l'interface lors du passage de l'onglet Boutons à un autre onglet
- Amélioré l'apparence de l'animation que le champ "+" joue après l'enregistrement d'une entrée. En particulier sur les versions de macOS antérieures à Ventura, où l'ombre du champ "+" apparaissait défectueuse pendant l'animation.
- Désactivé les notifications listant plusieurs boutons qui ont été capturés/ne sont plus capturés par Mac Mouse Fix qui apparaissaient lors du premier démarrage de l'application ou lors du chargement d'un préréglage. Je pensais que ces messages étaient distrayants et légèrement accablants et pas vraiment utiles dans ces contextes.
- Remanié l'écran d'octroi d'accès à l'accessibilité. Il affichera maintenant des informations sur la raison pour laquelle Mac Mouse Fix a besoin d'un accès à l'accessibilité directement au lieu de renvoyer vers le site web et il est un peu plus clair et a une mise en page plus agréable visuellement.
- Mis à jour le lien des remerciements dans l'onglet À propos.
- Amélioré les messages d'erreur lorsque Mac Mouse Fix ne peut pas être activé car une autre version est présente sur le système. Le message sera maintenant affiché dans une fenêtre d'alerte flottante qui reste toujours au-dessus des autres fenêtres jusqu'à ce qu'elle soit fermée au lieu d'une notification Toast qui disparaît lorsque vous cliquez n'importe où. Cela devrait faciliter le suivi des étapes de solution suggérées.
- Corrigé certains problèmes avec le rendu markdown sur les versions de macOS antérieures à Ventura. MMF utilisera maintenant une solution de rendu markdown personnalisée pour toutes les versions de macOS, y compris Ventura. Avant, nous utilisions une API système introduite dans Ventura mais cela conduisait à des incohérences. Markdown est utilisé pour ajouter des liens et de l'emphase au texte dans toute l'interface utilisateur.
- Amélioré les interactions autour de l'activation de l'accès à l'accessibilité.
- Corrigé un problème où la fenêtre de l'application s'ouvrait parfois sans afficher de contenu jusqu'à ce que vous passiez à l'un des onglets.
- Corrigé un problème avec le champ "+" où vous ne pouviez parfois pas ajouter une nouvelle action même si un effet de survol indiquait que vous pouviez entrer une action.
- Corrigé un blocage et plusieurs autres petits problèmes qui se produisaient parfois lors du déplacement du pointeur de la souris dans le champ "+".
- Corrigé un problème où une fenêtre contextuelle qui apparaît dans l'onglet Boutons lorsque votre souris ne semble pas correspondre aux paramètres de bouton actuels aurait parfois tout le texte en gras.
- Mis à jour toutes les mentions de l'ancienne licence MIT vers la nouvelle licence MMF. Les nouveaux fichiers créés pour le projet contiendront maintenant un en-tête généré automatiquement mentionnant la licence MMF.
- Fait en sorte que le passage à l'onglet Boutons active MMF pour le défilement. Sinon, vous ne pouviez pas enregistrer les gestes de Clic et défilement.
- Corrigé certains problèmes où les noms des boutons ne s'affichaient pas correctement dans le tableau des actions dans certaines situations.
- Corrigé un bug où la section d'essai sur l'écran À propos apparaissait buggée lors de l'ouverture de l'application puis du passage à l'onglet d'essai après l'expiration de l'essai.
- Corrigé un bug où le lien Activer la licence dans la section d'essai de l'onglet À propos ne réagissait parfois pas aux clics.
- Corrigé une fuite de mémoire lors de l'utilisation de la fonction "Clic et glisser" pour "Espaces & Mission Control".
- Activé le runtime renforcé sur l'application principale Mac Mouse Fix, améliorant la sécurité
- Beaucoup de nettoyage de code, restructuration du projet
- Plusieurs autres plantages corrigés
- Plusieurs fuites de mémoire corrigées
- Divers petits ajustements de texte dans l'interface utilisateur
- Les remaniements de plusieurs systèmes internes ont également amélioré la robustesse et le comportement dans les cas limites

## 8. Comment vous pouvez aider

Vous pouvez aider en partageant vos **idées**, **problèmes** et **retours** !

Le meilleur endroit pour partager vos **idées** et **problèmes** est l'[Assistant de retour](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Le meilleur endroit pour donner des retours **rapides** non structurés est la [Discussion de retour](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Vous pouvez également accéder à ces endroits depuis l'application dans l'onglet "**ⓘ À propos**".

**Merci** d'aider à faire de Mac Mouse Fix le meilleur possible ! 🙌 :)