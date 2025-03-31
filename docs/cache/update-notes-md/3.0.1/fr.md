Mac Mouse Fix **3.0.1** apporte plusieurs corrections de bugs et améliorations, ainsi qu'une **nouvelle langue** !

### Le vietnamien a été ajouté !

Mac Mouse Fix est maintenant disponible en 🇻🇳 vietnamien. Un grand merci à @nghlt [sur GitHub](https://GitHub.com/nghlt) !


### Corrections de bugs

- Mac Mouse Fix fonctionne maintenant correctement avec la **Permutation rapide d'utilisateur** !
  - La permutation rapide d'utilisateur permet de se connecter à un second compte macOS sans se déconnecter du premier compte.
  - Avant cette mise à jour, le défilement ne fonctionnait plus après une permutation rapide d'utilisateur. Maintenant, tout devrait fonctionner correctement.
- Correction d'un petit bug où la mise en page de l'onglet Boutons était trop large après le premier démarrage de Mac Mouse Fix.
- Le champ '+' fonctionne maintenant de manière plus fiable lors de l'ajout de plusieurs Actions rapidement.
- Correction d'un crash obscur signalé par @V-Coba dans le problème [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Autres améliorations

- **Le défilement est plus réactif** avec le paramètre 'Fluidité : Normal'.
  - La vitesse d'animation augmente maintenant lorsque vous tournez la molette plus rapidement. Ainsi, le défilement est plus réactif quand vous défilez rapidement tout en restant fluide quand vous défilez lentement.
  
- L'**accélération de la vitesse de défilement** est plus stable et prévisible.
- Mise en place d'un mécanisme pour **conserver vos paramètres** lors de la mise à jour vers une nouvelle version de Mac Mouse Fix.
  - Auparavant, Mac Mouse Fix réinitialisait tous vos paramètres après une mise à jour vers une nouvelle version si la structure des paramètres avait changé. Maintenant, Mac Mouse Fix tentera de mettre à jour la structure de vos paramètres et de conserver vos préférences.
  - Pour l'instant, cela ne fonctionne que lors de la mise à jour de 3.0.0 vers 3.0.1. Si vous mettez à jour depuis une version antérieure à 3.0.0, ou si vous _régressez_ de 3.0.1 _vers_ une version précédente, vos paramètres seront toujours réinitialisés.
- La mise en page de l'onglet Boutons s'adapte maintenant mieux aux différentes langues.
- Améliorations du [README GitHub](https://github.com/noah-nuebling/mac-mouse-fix#background) et d'autres documents.
- Amélioration des systèmes de localisation. Les fichiers de traduction sont maintenant automatiquement nettoyés et analysés pour détecter les problèmes potentiels. Il y a un nouveau [Guide de localisation](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) qui présente les problèmes détectés automatiquement ainsi que d'autres informations utiles et instructions pour les personnes qui souhaitent aider à traduire Mac Mouse Fix. Suppression de la dépendance à l'outil [BartyCrouch](https://github.com/FlineDev/BartyCrouch) qui était précédemment utilisé pour obtenir certaines de ces fonctionnalités.
- Amélioration de plusieurs textes de l'interface en anglais et en allemand.
- Nombreux nettoyages et améliorations sous le capot.

---

Consultez également les notes de version de [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - la plus grande mise à jour de Mac Mouse Fix à ce jour !