Mac Mouse Fix **3.0.4 Beta 1** améliore la confidentialité, l'efficacité et la fiabilité.\
Il introduit un nouveau système de licence hors ligne et corrige plusieurs bugs importants.

### Confidentialité et efficacité améliorées

- Introduit un nouveau système de validation de licence hors ligne qui minimise les connexions internet.
- L'application ne se connecte désormais à internet que lorsque c'est absolument nécessaire, protégeant votre vie privée et réduisant l'utilisation des ressources.
- L'application fonctionne complètement hors ligne pendant une utilisation normale lorsqu'elle est sous licence.

<details>
<summary><b>Informations détaillées sur la confidentialité</b></summary>
Les versions précédentes validaient les licences en ligne à chaque lancement, permettant potentiellement le stockage des journaux de connexion par des serveurs tiers (GitHub et Gumroad). Le nouveau système élimine les connexions inutiles – après l'activation initiale de la licence, il ne se connecte à internet que si les données de licence locales sont corrompues.
<br><br>
Bien qu'aucun comportement utilisateur n'ait jamais été enregistré par moi personnellement, l'ancien système permettait théoriquement aux serveurs tiers de journaliser les adresses IP et les heures de connexion. Gumroad pouvait également enregistrer votre clé de licence et potentiellement la corréler avec toute information personnelle enregistrée lors de votre achat de Mac Mouse Fix.
<br><br>
Je n'avais pas considéré ces subtils problèmes de confidentialité lors de la création du système de licence original, mais maintenant, Mac Mouse Fix est aussi privé et libre d'internet que possible !
<br><br>
Voir aussi <a href=https://gumroad.com/privacy>la politique de confidentialité de Gumroad</a> et mon <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>commentaire sur GitHub</a>.

</details>

### Corrections de bugs

- Correction d'un bug où macOS se bloquait parfois lors de l'utilisation de 'Cliquer et faire glisser' pour 'Spaces & Mission Control'.
- Correction d'un bug où les raccourcis clavier dans les Réglages Système étaient parfois supprimés lors de l'utilisation d'une action 'Clic' définie dans Mac Mouse Fix comme 'Mission Control'.
- Correction d'[un bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) où l'application cessait parfois de fonctionner et affichait une notification indiquant que les 'jours gratuits sont terminés' aux utilisateurs ayant déjà acheté l'application.
    - Si vous avez rencontré ce bug, je m'excuse sincèrement pour le désagrément. Vous pouvez demander un [remboursement ici](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).

### Améliorations techniques

- Implémentation d'un nouveau système 'MFDataClass' permettant une modélisation des données plus propre et des fichiers de configuration lisibles par l'homme.
- Ajout du support pour d'autres plateformes de paiement que Gumroad. Ainsi, à l'avenir, il pourrait y avoir des paiements localisés, et l'application pourrait être vendue dans différents pays !

### Abandon du support (non officiel) de macOS 10.14 Mojave

Mac Mouse Fix 3 prend officiellement en charge macOS 11 Big Sur et versions ultérieures. Cependant, pour les utilisateurs prêts à accepter quelques bugs et problèmes graphiques, Mac Mouse Fix 3.0.3 et versions antérieures pouvaient encore être utilisés sur macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 abandonne ce support et **nécessite désormais macOS 10.15 Catalina**.\
Je m'excuse pour tout désagrément causé par ce changement. Cette modification m'a permis d'implémenter le système de licence amélioré en utilisant des fonctionnalités Swift modernes. Les utilisateurs de Mojave peuvent continuer à utiliser Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) ou la [dernière version de Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). J'espère que c'est une bonne solution pour tout le monde.

*Édité avec l'excellente assistance de Claude.*

---

Consultez également la version précédente [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).