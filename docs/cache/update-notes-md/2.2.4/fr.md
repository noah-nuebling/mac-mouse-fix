Mac Mouse Fix **2.2.4** est maintenant notarisé ! Cette version inclut également quelques corrections de bugs et d'autres améliorations.

### **Notarisation**

Mac Mouse Fix 2.2.4 est maintenant 'notarisé' par Apple. Cela signifie qu'il n'y aura plus de messages indiquant que Mac Mouse Fix est potentiellement un 'Logiciel malveillant' lors de la première ouverture de l'application.

#### Contexte

La notarisation d'une application coûte 100 $ par an. J'y étais toujours opposé, car cela semblait hostile envers les logiciels gratuits et open source comme Mac Mouse Fix, et cela semblait également être un pas dangereux vers un contrôle et un verrouillage du Mac par Apple, comme ils le font avec les iPhone ou les iPad. Mais l'absence de notarisation a entraîné différents problèmes, notamment des [difficultés à ouvrir l'application](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) et même [plusieurs situations](https://github.com/noah-nuebling/mac-mouse-fix/issues/95) où personne ne pouvait plus utiliser l'application jusqu'à ce que je publie une nouvelle version.

Pour Mac Mouse Fix 3, j'ai pensé qu'il était enfin approprié de payer les 100 $ par an pour notariser l'application, puisque Mac Mouse Fix 3 est monétisé. ([En savoir plus](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Maintenant, Mac Mouse Fix 2 bénéficie également de la notarisation, ce qui devrait conduire à une expérience utilisateur plus facile et plus stable.

### **Corrections de bugs**

- Correction d'un problème où le curseur disparaissait puis réapparaissait à un endroit différent lors de l'utilisation d'une action 'Cliquer-glisser' pendant un enregistrement d'écran ou lors de l'utilisation du logiciel [DisplayLink](https://www.synaptics.com/products/displaylink-graphics).
- Correction d'un problème d'activation de Mac Mouse Fix sous macOS 10.14 Mojave et possiblement aussi sous des versions plus anciennes de macOS.
- Amélioration de la gestion de la mémoire, corrigeant potentiellement un plantage de l'application 'Mac Mouse Fix Helper' qui survenait lors du détachement d'une souris de votre ordinateur. Voir la Discussion [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Autres améliorations**

- La fenêtre que l'application affiche pour vous informer qu'une nouvelle version de Mac Mouse Fix est disponible prend maintenant en charge JavaScript. Cela permet aux notes de mise à jour d'être plus jolies et plus faciles à lire. Par exemple, les notes de mise à jour peuvent maintenant afficher les [Alertes Markdown](https://github.com/orgs/community/discussions/16925) et plus encore.
- Suppression d'un lien vers la page https://macmousefix.com/about/ de l'écran "Accorder l'accès d'accessibilité à Mac Mouse Fix Helper". C'est parce que la page À propos n'existe plus et a été remplacée pour l'instant par le [README GitHub](https://github.com/noah-nuebling/mac-mouse-fix).
- Cette version inclut maintenant des fichiers dSYM qui peuvent être utilisés par n'importe qui pour décoder les rapports de plantage de Mac Mouse Fix 2.2.4.
- Quelques nettoyages et améliorations sous le capot.

---

Consultez également la version précédente [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).