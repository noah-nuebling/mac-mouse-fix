Mac Mouse Fix **3.0.4** améliore la confidentialité, l'efficacité et la fiabilité.\
Cette version introduit un nouveau système de licence hors ligne et corrige plusieurs bugs importants.

### Confidentialité et efficacité améliorées

La version 3.0.4 introduit un nouveau système de validation de licence hors ligne qui minimise autant que possible les connexions internet.\
Cela améliore la confidentialité et économise les ressources système de ton ordinateur.\
Une fois sous licence, l'application fonctionne maintenant 100% hors ligne !

<details>
<summary><b>Clique ici pour plus de détails</b></summary>
Les versions précédentes validaient les licences en ligne à chaque lancement, permettant potentiellement aux serveurs tiers (GitHub et Gumroad) de stocker des journaux de connexion. Le nouveau système élimine les connexions inutiles – après l'activation initiale de la licence, il ne se connecte à internet que si les données de licence locales sont corrompues.
<br><br>
Bien qu'aucun comportement utilisateur n'ait jamais été enregistré par moi personnellement, le système précédent permettait théoriquement aux serveurs tiers d'enregistrer les adresses IP et les heures de connexion. Gumroad pouvait également enregistrer ta clé de licence et potentiellement la corréler aux informations personnelles qu'ils ont enregistrées sur toi lors de l'achat de Mac Mouse Fix.
<br><br>
Je n'avais pas pris en compte ces problèmes subtils de confidentialité lors de la création du système de licence original, mais maintenant, Mac Mouse Fix est aussi privé et indépendant d'internet que possible !
<br><br>
Consulte également la <a href=https://gumroad.com/privacy>politique de confidentialité de Gumroad</a> et ce <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>commentaire GitHub</a> de ma part.

</details>

### Corrections de bugs

- Correction d'un bug où macOS se bloquait parfois lors de l'utilisation de « Cliquer et glisser » pour « Spaces et Mission Control ».
- Correction d'un bug où les raccourcis clavier dans Réglages Système étaient parfois supprimés lors de l'utilisation des actions « Clic » de Mac Mouse Fix telles que « Mission Control ».
- Correction d'[un bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) où l'application cessait parfois de fonctionner et affichait une notification indiquant que les « Jours gratuits sont terminés » aux utilisateurs ayant déjà acheté l'application.
    - Si tu as rencontré ce bug, je m'excuse sincèrement pour le désagrément. Tu peux demander un [remboursement ici](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Amélioration de la façon dont l'application récupère sa fenêtre principale, ce qui peut avoir corrigé un bug où l'écran « Activer la licence » ne s'affichait parfois pas.

### Améliorations de l'ergonomie

- Il est maintenant impossible de saisir des espaces et des sauts de ligne dans le champ de texte de l'écran « Activer la licence ».
    - C'était une source de confusion courante, car il est très facile de sélectionner accidentellement un saut de ligne caché lors de la copie de ta clé de licence depuis les e-mails de Gumroad.
- Ces notes de mise à jour sont automatiquement traduites pour les utilisateurs non anglophones (Propulsé par Claude). J'espère que c'est utile ! Si tu rencontres des problèmes, fais-le-moi savoir. C'est un premier aperçu d'un nouveau système de traduction que je développe depuis un an.

### Abandon du support (non officiel) pour macOS 10.14 Mojave

Mac Mouse Fix 3 prend officiellement en charge macOS 11 Big Sur et versions ultérieures. Cependant, pour les utilisateurs prêts à accepter quelques bugs et problèmes graphiques, Mac Mouse Fix 3.0.3 et versions antérieures pouvaient encore être utilisés sur macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 abandonne ce support et **nécessite maintenant macOS 10.15 Catalina**.\
Je m'excuse pour tout désagrément causé par ce changement. Cette modification m'a permis d'implémenter le système de licence amélioré en utilisant les fonctionnalités Swift modernes. Les utilisateurs de Mojave peuvent continuer à utiliser Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) ou la [dernière version de Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). J'espère que c'est une bonne solution pour tout le monde.

### Améliorations techniques

- Implémentation d'un nouveau système « MFDataClass » permettant une modélisation de données plus puissante tout en gardant le fichier de configuration de Mac Mouse Fix lisible et modifiable par l'utilisateur.
- Ajout de la prise en charge de plateformes de paiement autres que Gumroad. Ainsi, à l'avenir, il pourrait y avoir des paiements localisés, et l'application pourrait être vendue dans différents pays.
- Amélioration de la journalisation qui me permet de créer des « Versions de débogage » plus efficaces pour les utilisateurs qui rencontrent des bugs difficiles à reproduire.
- De nombreuses autres petites améliorations et travaux de nettoyage.

*Édité avec l'excellente assistance de Claude.*

---

Consulte également la version précédente [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).