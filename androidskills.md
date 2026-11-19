# Guide de développement Android — UpChat

**Statut :** consignes de plateforme pour les travaux futurs. Ce document n’autorise, à lui seul, aucun changement de code, dépendance, permission, SDK ou workflow. Il complète le cahier des charges UpChat et doit être appliqué fichier par fichier après accord explicite.

Dernière mise à jour : 19 novembre 2026.

## 1. Contexte et décisions confirmées

UpChat est une application Flutter/Dart pensée d’abord pour les échanges locaux, sans compte requis pour la messagerie de proximité. Android est la plateforme native prioritaire. La version iPhone actuellement décrite dans le projet est une version Web ouverte dans un WebView ; ne pas supposer qu’elle possède déjà les fonctions natives de Bluetooth ou de proximité.

Nearby Connections est à traiter comme un transport Android–Android uniquement. Toute interopérabilité Android–iPhone doit faire l’objet d’un protocole commun et d’une preuve de faisabilité, notamment en BLE ou sur le même Wi‑Fi/point d’accès. La décision confirmée pour les appels est : **média d’appel transporté par le Wi‑Fi entre téléphones ; casque Bluetooth utilisé comme périphérique audio, pas comme transport réseau de l’appel**. Ne jamais présenter un appel comme transporté par Bluetooth.

L’utilisateur a supprimé le plafond fixe de taille APK : **aucune limite dure en Mo**. L’économie reste un objectif : éviter le poids inutile, mesurer et rapporter la taille de l’APK universel et des APK par ABI à chaque build concerné, et justifier les coûts importants avant d’ajouter une dépendance ou un média embarqué.

La messagerie locale ne doit pas dépendre d’un serveur propre. Tout relais serveur, service de notification ou transport Internet nécessite une décision et une autorisation distinctes.

Les zones provisoires M0 validées par l’utilisateur sont des zones de **non-régression protégées**, pas des fonctions dont le fonctionnement a déjà été prouvé : navigation/thèmes, liste et discussion, stories, profil/réglages, sécurité locale et proximité Android. Les résultats RG-01 à RG-10 sur appareil restent à consigner séparément.

## 2. Discipline de changement

- Ne modifier que les chemins approuvés pour la tâche en cours. Aucun nettoyage, refactor, reformattage massif ni changement de comportement au passage.
- Demander l’accord avant tout changement de permission du manifeste, dépendance, version Flutter/Gradle/NDK, SDK, workflow CI, modèle de données, stockage ou texte d’interface existant.
- Une fonction nouvelle est isolée, derrière un drapeau désactivé par défaut, avec plan de retour arrière. Un POC de réseau ou de performance précède toute promesse produit.
- Préserver Provider comme gestion d’état existante, Hive chiffré et les schémas de données existants. Toute migration doit être idempotente, sauvegardée et testée ; aucune donnée ne doit disparaître silencieusement.
- Commits atomiques sur branche dédiée ; ne jamais modifier directement `main`. Rapporter les fichiers exacts et preuves de test. Une compilation verte ne vaut pas preuve des tests non exécutés.

## 3. Transports et limites Android

### Nearby Connections, Bluetooth et Wi‑Fi

Garder chaque transport derrière une interface claire qui expose ses plateformes, ses capacités, ses prérequis, son débit attendu et ses limites. Ne pas faire dépendre les vues ou les modèles métier directement d’une API native.

- `nearby_connections` / Nearby Connections : utiliser uniquement pour des scénarios Android compatibles ; ne pas en déduire une compatibilité Android–iPhone.
- BLE : envisager un protocole commun Android/iOS pour découverte et petits échanges seulement après POC, accord sur le protocole et tests réels. Limiter les données diffusées et renouveler les identifiants selon la conception approuvée.
- Wi‑Fi local : le cas visé est deux téléphones sur le même réseau ou le même point d’accès partagé, sans dépendance à Internet. Vérifier le mDNS/Bonjour, les pare-feu et l’isolation des clients du routeur. Wi‑Fi Direct/Nearby côté Android ne doit pas être confondu avec l’interopérabilité Wi‑Fi locale avec iPhone.
- Gros fichiers et appels : mesurer débit, reprise, fiabilité, batterie et échauffement sur appareils avant décision. Aucun transfert ou appel ne doit basculer secrètement vers Internet.
- Appels audio/vidéo : le cahier des charges prévoit un POC préalable et un transport local Wi‑Fi, éventuellement WebRTC après autorisation. Le casque Bluetooth est une sortie/entrée audio gérée par le système ; le flux d’appel n’est pas transporté en Bluetooth.

### Permissions et confidentialité

N’ajouter aucune permission sans approbation. Demander les permissions au moment utile avec une explication française, prévoir refus/révocation et proposer une dégradation propre plutôt qu’un plantage.

Pour les apps ciblant Android 12/API 31 ou supérieur, les usages Bluetooth sont séparés : `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE` et `BLUETOOTH_CONNECT` doivent correspondre aux opérations réellement utilisées et sont soumis à consentement runtime. Déclarer `neverForLocation` uniquement si les résultats ne servent réellement pas à dériver la position ; cette option peut filtrer certains beacons. Ne garder une permission de localisation que si une fonction l’exige réellement ou pour la compatibilité de versions/API concernées.

`NEARBY_WIFI_DEVICES` ne s’applique pas à toute opération Wi‑Fi indistinctement : certaines API de gestion Wi‑Fi la requièrent sur Android 13/API 33+, tandis que certaines API exigent encore la localisation. Choisir la permission après avoir identifié l’API exacte ; ne pas l’ajouter par précaution.

Aucun contenu de message, média, clé privée, identifiant personnel ou position GPS exacte dans les logs, traces, notifications de diagnostic ou rapports CI. Aucun suivi ni outil d’analytique tiers sans décision explicite.

### Tâches de fond, batterie et notifications

Ne pas promettre une présence permanente. Pour tout travail de fond réellement visible et continu, étudier d’abord une API spécialisée ; si un service au premier plan est nécessaire, déclarer le type adapté et ses permissions/runtime prerequisites. À partir d’Android 14/API 34, le type de foreground service doit être déclaré et justifié. L’utilisateur doit voir la notification correspondante. Prévoir cycles de scan, arrêt sur demande, gestion des optimisations batterie constructeur et mesures de consommation ; ne pas lancer du scan continu par défaut.

### UWB et distance

UWB est optionnel et dépend du matériel et de l’API disponibles. Vérifier la capacité sur l’appareil au runtime et obtenir le consentement mutuel. La négociation de session doit utiliser un canal hors bande sécurisé. Sans matériel compatible, afficher seulement un indicateur qualitatif fondé sur le signal, jamais une valeur numérique qui prétend à une précision de distance. Tester les limites de réception en arrière-plan au lieu de les supposer.

## 4. Architecture, sécurité et interface

Privilégier des modules additifs : `core/identity`, `core/crypto`, `transport/`, `router/` et `features/` selon le cahier des charges, sans déplacer ni remplacer l’existant sans accord. Les contrats de transport et messages doivent être validés et testés avec entrées mal formées, relecture/rejeu, doublons, expiration et interruptions.

Ne jamais écrire de cryptographie maison. Toute fonction de chiffrement ou de clé doit utiliser une bibliothèque éprouvée, vérifiée pour licence, maintenance, plateformes, versions et poids. Stocker les clés dans un stockage sécurisé du système ; Hive chiffré ne dispense pas de protéger la clé. Les journaux ne contiennent aucune charge utile.

Conserver l’interface UpChat en français, l’accent bleu unique et les thèmes clair/sombre/OLED existants. Respecter Material 3, des cibles tactiles d’au moins 48 dp, le contraste, TalkBack, la taille de texte, la réduction des animations/transparences et des états annoncés textuellement, pas seulement par la couleur.

## 5. Build et validation Android

La configuration de CI versionnée est la source de vérité ; la version de Flutter, Java, Android SDK, Gradle, NDK et les commandes ne sont pas modifiées sans accord. Le run du 19 novembre 2026 `44622970168` a compilé avec succès les jobs `build-apk` et `build-web`, mais n’a pas exécuté `flutter analyze`, `flutter test` ni RG-01 à RG-10 sur appareil. Ne pas transformer ce résultat en déclaration de validation fonctionnelle complète.

À chaque tâche concernée, consigner au minimum :

1. `flutter analyze` et `flutter test` (ou indiquer précisément pourquoi ils n’ont pas été lancés) ;
2. compilation release Android sur runner compatible, numéro du run et résultat par job ;
3. taille exacte universelle et par ABI, avant/après, sans plafond dur mais avec objectif d’économie ;
4. permissions effectives du manifeste et toute variation ;
5. scénario manuel sur le Samsung et résultats RG pertinents, démarrage et consommation lorsqu’ils sont concernés.

Matrice de non-régression à utiliser : démarrage froid/chaud, thèmes, envoi/réception à deux appareils, historique, création/lecture/expiration des stories, marges clavier, biométrie, mise à jour avec données existantes, APK/permissions, navigation/retour. Une ligne non testée reste explicitement « non testée ».

Le sandbox de développement ARM64 n’exécute pas le Dart SDK x64 épinglé dans Flutter 3.47.8. Pour cette version, le build Android validé utilise un runner x64 de GitHub Actions ; ne pas prétendre qu’un build Android local ARM64 a été fait.

## 6. Références officielles

- [Permissions Bluetooth Android](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)
- [Permissions Wi‑Fi Android](https://developer.android.com/develop/connectivity/wifi/wifi-permissions)
- [Types de services au premier plan Android](https://developer.android.com/develop/background-work/services/fgs/service-types)
- [UWB Android](https://developer.android.com/develop/connectivity/uwb)

Le cahier des charges détaillé a été fourni en pièce jointe de la tâche ; il n’est pas versionné dans ce dépôt.
