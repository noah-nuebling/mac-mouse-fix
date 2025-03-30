Mac Mouse Fix **3.0.1** porta diverses correccions d'errors i millores, juntament amb un **nou idioma**!

### S'ha afegit el vietnamita!

Mac Mouse Fix ara està disponible en 🇻🇳 vietnamita. Moltes gràcies a @nghlt [a GitHub](https://GitHub.com/nghlt)!

### Correccions d'errors

- Mac Mouse Fix ara funciona correctament amb el **Canvi Ràpid d'Usuari**!
  - El Canvi Ràpid d'Usuari és quan inicies sessió en un segon compte de macOS sense tancar la sessió del primer compte.
  - Abans d'aquesta actualització, el desplaçament deixava de funcionar després d'un canvi ràpid d'usuari. Ara tot hauria de funcionar correctament.
- S'ha corregit un petit error on la disposició de la pestanya Botons era massa ampla després d'iniciar Mac Mouse Fix per primera vegada.
- S'ha fet que el camp '+' funcioni de manera més fiable quan s'afegeixen diverses Accions ràpidament.
- S'ha corregit un error obscur reportat per @V-Coba a l'Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Altres millores

- **El desplaçament se sent més receptiu** quan s'utilitza la configuració 'Suavitat: Regular'.
  - La velocitat d'animació ara esdevé més ràpida a mesura que mous la roda de desplaçament més ràpidament. D'aquesta manera, se sent més receptiu quan et desplaces ràpidament mentre se sent igual de suau quan et desplaces lentament.

- S'ha fet que **l'acceleració de la velocitat de desplaçament** sigui més estable i predictible.
- S'ha implementat un mecanisme per **mantenir la configuració** quan actualitzes a una nova versió de Mac Mouse Fix.
  - Abans, Mac Mouse Fix restablia tota la configuració després d'actualitzar a una nova versió, si l'estructura de la configuració canviava. Ara, Mac Mouse Fix intentarà actualitzar l'estructura de la teva configuració i mantenir les teves preferències.
  - De moment, això només funciona quan s'actualitza de 3.0.0 a 3.0.1. Si estàs actualitzant des d'una versió anterior a 3.0.0, o si fas una _degradació_ de 3.0.1 _a_ una versió anterior, la teva configuració encara es restablirà.
- La disposició de la pestanya Botons ara adapta millor la seva amplada a diferents idiomes.
- Millores al [README de GitHub](https://github.com/noah-nuebling/mac-mouse-fix#background) i altres documents.
- Millores als sistemes de localització. Els arxius de traducció ara es netegen i s'analitzen automàticament per detectar possibles problemes. Hi ha una nova [Guia de Localització](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) que mostra qualsevol problema detectat automàticament juntament amb altra informació útil i instruccions per a les persones que volen ajudar a traduir Mac Mouse Fix. S'ha eliminat la dependència de l'eina [BartyCrouch](https://github.com/FlineDev/BartyCrouch) que s'utilitzava anteriorment per obtenir part d'aquesta funcionalitat.
- S'han millorat diversos textos de la interfície en anglès i alemany.
- Moltes millores i neteges internes.

---

També consulta les notes de llançament de [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - la major actualització de Mac Mouse Fix fins ara!