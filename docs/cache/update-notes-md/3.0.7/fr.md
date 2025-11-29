Mac Mouse Fix **3.0.7** corrige plusieurs bugs importants.

### Corrections de bugs

- L'application fonctionne à nouveau sur les **anciennes versions de macOS** (macOS 10.15 Catalina et macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 ne pouvait pas être activé sous ces versions de macOS car la fonctionnalité améliorée « Retour » et « Avancer » introduite dans Mac Mouse Fix 3.0.6 tentait d'utiliser des API système de macOS qui n'étaient pas disponibles.
- Correction de problèmes avec la fonctionnalité **« Retour » et « Avancer »**
    - La fonctionnalité améliorée « Retour » et « Avancer » introduite dans Mac Mouse Fix 3.0.6 utilisera désormais toujours le « thread principal » pour demander à macOS quelles touches simuler pour revenir en arrière et avancer dans l'application que tu utilises. \
    Cela peut prévenir les plantages et les comportements peu fiables dans certaines situations.
- Tentative de correction du bug où **les paramètres étaient réinitialisés aléatoirement** (Voir ces [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - J'ai réécrit le code qui charge le fichier de configuration de Mac Mouse Fix pour le rendre plus robuste. Lorsque de rares erreurs du système de fichiers de macOS se produisaient, l'ancien code pouvait parfois penser à tort que le fichier de configuration était corrompu et le réinitialiser aux valeurs par défaut.
- Réduction des risques d'un bug où **le défilement cesse de fonctionner**     
     - Ce bug ne peut pas être entièrement résolu sans modifications plus profondes, qui causeraient probablement d'autres problèmes. \
      Cependant, pour le moment, j'ai réduit la fenêtre temporelle où un « deadlock » peut se produire dans le système de défilement, ce qui devrait au moins diminuer les chances de rencontrer ce bug. Cela rend également le défilement légèrement plus efficace. 
    - Ce bug présente des symptômes similaires – mais je pense une cause sous-jacente différente – au bug « Le défilement cesse de fonctionner par intermittence » qui a été traité dans la dernière version 3.0.6.
    - (Merci à Joonas pour les diagnostics !) 

Merci à tous d'avoir signalé les bugs ! 

---

Consulte également la version précédente [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).