Mac Mouse Fix **3.0.8** résout des problèmes d'interface et plus encore.

### **Problèmes d'interface**

- Désactivation du nouveau design sur macOS 26 Tahoe. Maintenant l'application aura l'apparence et fonctionnera comme sur macOS 15 Sequoia.
    - J'ai fait cela parce que certains éléments d'interface redessinés par Apple ont encore des problèmes. Par exemple, les boutons '-' dans l'onglet 'Boutons' n'étaient pas toujours cliquables.
    - L'interface peut maintenant sembler un peu dépassée sur macOS 26 Tahoe. Mais elle devrait être entièrement fonctionnelle et soignée comme avant.
- Correction d'un bug où la notification 'Les jours gratuits sont terminés' restait bloquée dans le coin supérieur droit de l'écran.
    - Merci à [Sashpuri](https://github.com/Sashpuri) et d'autres pour l'avoir signalé !

### **Améliorations de l'interface**

- Désactivation du bouton feu vert dans la fenêtre principale de Mac Mouse Fix.
    - Le bouton ne faisait rien, puisque la fenêtre ne peut pas être redimensionnée manuellement.
- Correction d'un problème où certaines lignes horizontales dans le tableau de l'onglet 'Boutons' étaient trop sombres sous macOS 26 Tahoe.
- Correction d'un bug où le message "Le bouton principal de la souris ne peut pas être utilisé" dans l'onglet 'Boutons' était parfois coupé sous macOS 26 Tahoe.
- Correction d'une faute de frappe dans l'interface allemande. Avec l'aimable contribution de l'utilisateur GitHub [i-am-the-slime](https://github.com/i-am-the-slime). Merci !
- Résolution d'un problème où la fenêtre MMF clignotait parfois brièvement à la mauvaise taille lors de l'ouverture de la fenêtre sur macOS 26 Tahoe.

### **Autres changements**

- Amélioration du comportement lors de la tentative d'activation de Mac Mouse Fix alors que plusieurs instances de Mac Mouse Fix sont en cours d'exécution sur l'ordinateur.
    - Mac Mouse Fix essaiera maintenant de désactiver l'autre instance de Mac Mouse Fix de manière plus diligente.
    - Cela peut améliorer les cas limites où Mac Mouse Fix ne pouvait pas être activé.
- Modifications et nettoyage en coulisses.

---

Découvre aussi les nouveautés de la version précédente [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).