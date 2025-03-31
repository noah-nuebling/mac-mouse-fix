Consultez également **les nouveautés** de la [3.0.0 Beta 3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-3) !

---

**3.0.0 Beta 4** apporte une nouvelle option **"Restaurer les paramètres par défaut..."** ainsi que de nombreuses **améliorations** et **corrections de bugs** !

Voici **tout ce qui est nouveau** :

## 1. Option "Restaurer les paramètres par défaut..."

Il y a maintenant un bouton "**Restaurer les paramètres par défaut...**" dans l'onglet "Boutons".
Cela vous permet de vous sentir encore plus **à l'aise** pour **expérimenter** avec les paramètres.

Il existe **2 configurations par défaut** :

1. Le "Paramètre par défaut pour les souris avec **5+ boutons**" est super puissant et confortable. En fait, il vous permet de faire **tout** ce que vous faites sur un **trackpad**. Tout cela en utilisant les 2 **boutons latéraux** qui sont juste là où repose votre **pouce** ! Mais bien sûr, il n'est disponible que sur les souris avec 5 boutons ou plus.
2. Le "Paramètre par défaut pour les souris avec **3 boutons**" vous permet toujours de faire les **choses les plus importantes** que vous faites sur un trackpad - même sur une souris qui n'a que 3 boutons.

J'ai fait de mon mieux pour rendre cette fonctionnalité **intelligente** :

- Quand vous lancez MMF pour la première fois, il **sélectionnera automatiquement** le préréglage qui **convient le mieux à votre souris**.
- Lorsque vous restaurez les paramètres par défaut, Mac Mouse Fix vous **montrera** quel **modèle de souris** vous utilisez et son **nombre de boutons**, pour que vous puissiez facilement choisir lequel des deux préréglages utiliser. Il **présélectionnera** également le préréglage qui **convient le mieux à votre souris**.
- Lorsque vous passez à une **nouvelle souris** qui ne correspond pas à vos paramètres actuels, une fenêtre contextuelle dans l'onglet Boutons vous **rappellera** comment **charger** les paramètres recommandés pour votre souris !
- Toute l'**interface** autour de cette fonction est très **simple**, **belle** et **s'anime** joliment.

J'espère que vous trouverez cette fonctionnalité **utile** et **simple à utiliser** ! Mais faites-moi savoir si vous rencontrez des problèmes.
Quelque chose est-il **bizarre** ou **peu intuitif** ? Les **fenêtres contextuelles** apparaissent-elles **trop souvent** ou dans des **situations inappropriées** ? **Faites-moi part** de votre expérience !

## 2. Mac Mouse Fix temporairement gratuit dans certains pays

Il y a certains **pays** où le **système de paiement** Gumroad de Mac Mouse Fix ne **fonctionne pas** actuellement.
Mac Mouse Fix est maintenant **gratuit** dans **ces pays** jusqu'à ce que je puisse proposer une méthode de paiement alternative !

Si vous êtes dans l'un des pays gratuits, ces informations seront **affichées** dans l'**onglet À propos** et lors de la **saisie d'une clé de licence**

S'il est **impossible d'acheter** Mac Mouse Fix dans votre pays, mais qu'il n'est pas encore **gratuit** dans votre pays - faites-le moi savoir et je rendrai Mac Mouse Fix gratuit dans votre pays aussi !

## 3. Un bon moment pour commencer à traduire !

Avec la Beta 4, j'ai **implémenté tous les changements d'interface** que j'avais prévus pour Mac Mouse Fix 3. Je ne m'attends donc plus à de grands changements d'interface jusqu'à la sortie de Mac Mouse Fix 3.

Si vous attendiez parce que vous pensiez que l'interface allait encore changer, c'est **le bon moment** pour commencer à **traduire** l'application dans votre langue !

Pour **plus d'informations** sur la traduction de l'application, consultez **[Notes de version 3.0.0 Beta 1](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-1.1) > 9. Internationalisation**

## 4. Tout le reste

Outre les changements listés ci-dessus, la Beta 4 comprend de nombreuses **corrections de bugs**, **ajustements** et **améliorations** :

### Interface utilisateur

#### Corrections de bugs

- Correction d'un bug où les liens de l'onglet À propos s'ouvraient en boucle en cliquant n'importe où dans la fenêtre. Merci à l'utilisateur GitHub [DingoBits](https://github.com/DingoBits) qui a corrigé cela !
- Correction de certains symboles dans l'application qui ne s'affichaient pas correctement sur les anciennes versions de macOS
- Masquage des barres de défilement dans le Tableau d'actions. Merci à l'utilisateur GitHub [marianmelinte93](https://github.com/marianmelinte93) qui m'a fait prendre conscience de ce problème dans [ce commentaire](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366#discussioncomment-3728994) !
- Correction d'un problème où le retour sur les fonctionnalités réactivées automatiquement lorsque vous ouvrez l'onglet correspondant dans l'interface (après avoir désactivé cette fonctionnalité depuis la barre de menu) ne s'affichait pas sur macOS Monterey et versions antérieures. Merci encore à [marianmelinte93](https://github.com/marianmelinte93) d'avoir signalé le problème.
- Ajout de la localisabilité manquante et des traductions allemandes pour l'option "Cliquer pour faire défiler pour se déplacer entre les espaces"
- Correction d'autres petits problèmes de localisabilité
- Ajout de traductions allemandes manquantes
- Les notifications qui s'affichent lorsqu'un bouton est capturé / n'est plus capturé fonctionnent maintenant correctement lorsque certains boutons ont été capturés et d'autres décapturés en même temps.

#### Améliorations

- Suppression de l'option "Cliquer et faire défiler pour le sélecteur d'applications". Elle était un peu bugguée et je ne pense pas qu'elle était très utile.
- Ajout de l'option "Cliquer et faire défiler pour pivoter".
- Ajustement de la mise en page du menu "Mac Mouse Fix" dans la barre de menu.
- Ajout du bouton "Acheter Mac Mouse Fix" dans le menu "Mac Mouse Fix" de la barre de menu.
- Ajout d'un texte d'aide sous l'option "Afficher dans la barre de menu". L'objectif est de rendre plus visible le fait que l'élément de la barre de menu peut être utilisé pour activer ou désactiver rapidement des fonctionnalités
- Les messages "Merci d'avoir acheté Mac Mouse Fix" sur l'écran À propos peuvent maintenant être entièrement personnalisés par les traducteurs.
- Amélioration des indications pour les traducteurs
- Amélioration des textes de l'interface concernant l'expiration de l'essai
- Amélioration des textes de l'interface dans l'onglet À propos
- Ajout de mises en évidence en gras à certains textes de l'interface pour améliorer la lisibilité
- Ajout d'une alerte lors du clic sur le lien "M'envoyer un email" dans l'onglet À propos.
- Modification de l'ordre de tri du Tableau d'actions. Les actions Clic et Défilement s'afficheront maintenant avant les actions Clic et Glisser. Cela me semble plus naturel car les lignes du tableau sont maintenant triées selon la puissance de leurs déclencheurs (Clic < Défilement < Glisser).
- L'application mettra maintenant à jour le périphérique activement utilisé lors de l'interaction avec l'interface. C'est utile car certains éléments de l'interface sont maintenant basés sur l'appareil que vous utilisez. (Voir la nouvelle fonction "Restaurer les paramètres par défaut...")
- Une notification indiquant quels boutons ont été capturés / ne sont plus capturés s'affiche maintenant lors du premier lancement de l'application.
- Plus d'améliorations aux notifications qui s'affichent lorsqu'un bouton a été capturé / n'est plus capturé
- Rendu impossible l'ajout accidentel d'espaces supplémentaires lors de l'activation d'une clé de licence

### Souris

#### Corrections de bugs

- Amélioration de la simulation de défilement pour envoyer correctement des "deltas à point fixe". Cela résout un problème où la vitesse de défilement était trop lente dans certaines applications comme Safari avec le défilement fluide désactivé.
- Correction d'un problème où la fonction "Clic et glisser pour Mission Control & Spaces" se bloquait parfois quand l'ordinateur était lent
- Correction d'un problème où le CPU était toujours utilisé par Mac Mouse Fix lors du déplacement de la souris après avoir utilisé la fonction "Clic et glisser pour défiler & naviguer"

#### Améliorations

- Grande amélioration de la réactivité du défilement pour zoomer dans les navigateurs basés sur Chromium comme Chrome, Brave ou Edge

### Sous le capot

#### Corrections de bugs

- Correction d'un problème où Mac Mouse Fix ne fonctionnait pas correctement après l'avoir déplacé dans un dossier différent alors qu'il était activé
- Correction de certains problèmes lors de l'activation de Mac Mouse Fix alors qu'une autre instance de Mac Mouse Fix était toujours activée. (C'est parce qu'Apple m'a permis de changer l'ID du bundle de "com.nuebling.mac-mouse-fixxx" utilisé dans la Beta 3 pour revenir à l'original "com.nuebling.mac-mouse-fix". Je ne sais pas pourquoi.)

#### Améliorations

- Cette version beta et les futures versions fourniront des informations de débogage plus détaillées
- Nettoyage et améliorations sous le capot. Suppression de l'ancien code pré-10.13. Nettoyage des frameworks et dépendances. Le code source est maintenant plus facile à utiliser et plus pérenne.