# Guide de développement iOS — UpChat

**Statut :** consignes de plateforme pour les travaux futurs. Ce document complète le cahier des charges UpChat ; il ne vaut pas autorisation d’ajouter du code natif, une permission, une capacité Xcode, une dépendance ou un service réseau.

Dernière mise à jour : 19 novembre 2026.

## 1. Contexte iPhone et décisions confirmées

Le contexte projet indique que l’iPhone utilise actuellement la version Web dans un WebView. Ne pas présenter cette version comme une application iOS native testée. Ne pas lui attribuer automatiquement les capacités de Core Bluetooth, Wi‑Fi local, UWB, caméra en arrière-plan ou notifications natives. La version Web ne gère pas le Bluetooth selon le cahier des charges ; tout comportement de proximité doit être validé sur la cible réelle.

Nearby Connections est Android seulement. Pour un lien Android–iPhone, le cahier des charges prévoit un protocole interopérable à étudier, ou des téléphones connectés au même réseau Wi‑Fi/point d’accès partagé. La décision confirmée pour les appels est : **média transporté par Wi‑Fi local entre téléphones ; casque Bluetooth comme périphérique audio, jamais comme transport de l’appel**. Aucun appel ne passe par Bluetooth.

L’utilisateur a supprimé le plafond fixe de taille APK : **pas de maximum dur en Mo**. Garder l’économie comme principe : minimiser les dépendances et actifs lourds, mesurer les artefacts Android et expliciter les compromis, sans refuser une fonction uniquement parce qu’elle dépasserait l’ancien plafond de 30 Mo.

La messagerie locale ne doit pas dépendre d’un serveur propre. Tout relais serveur, service de notification ou transport Internet nécessite une décision et une autorisation distinctes.

Zones M0 provisoires validées comme protégées : navigation/thèmes, liste et discussion, stories, profil/réglages, sécurité locale et proximité Android. Cette validation définit un périmètre de non-régression ; elle ne signifie pas que les parcours iPhone, la version Web ou RG-01 à RG-10 ont été exécutés avec succès.

## 2. Discipline de travail

- N’intervenir que sur les fichiers approuvés, et attendre l’accord avant toute modification d’`Info.plist`, entitlements, modes d’arrière-plan, permissions, dépendances, version d’outil, schéma de données ou CI.
- Garder les adaptations iOS dans une couche de plateforme minimale et derrière une interface ; ne pas forcer du code natif dans les widgets Flutter ni remplacer le comportement existant.
- Toute nouvelle fonction est un POC séparé, additif, désactivé par défaut derrière un feature flag lorsque c’est une fonction produit. Prévoir preuves, scénario de retour arrière et test sur appareil réel.
- Ne pas confondre guide de plateforme, capacité documentée, présence sur un modèle précis et capacité actuellement disponible dans UpChat. Distinguer systématiquement « pris en charge par iOS », « appareil compatible », « implémenté dans UpChat » et « vérifié sur iPhone ».

## 3. Réseau local et appels

### Wi‑Fi local, Bonjour et autorisation système

Le cas interopérable visé est le même réseau Wi‑Fi ou le même point d’accès partagé, sans Internet. Wi‑Fi Direct/Nearby côté Android n’est pas un transport disponible de la même façon sur iPhone. Avant toute implémentation, réaliser le POC Android–iPhone demandé : découverte, connexion, envoi/retour, débit, reprise, fiabilité, batterie et comportement avec l’isolation client du routeur.

Si une future app iOS native accède au réseau local, respecter la confidentialité iOS : expliquer l’usage avec `NSLocalNetworkUsageDescription`. Si Bonjour est utilisé, déclarer les types de services nécessaires dans `NSBonjourServices`. Gérer les états non demandé, autorisé et refusé, notamment quand un appel réseau local survient en arrière-plan. Ne demander aucune capacité multicast ni permission non justifiée.

La version Web/WebView actuelle ne doit pas être supposée capable d’effectuer cette découverte Bonjour native. Toute passerelle Web, API native ou permission correspondante doit être analysée et autorisée séparément.

### Audio et vidéo

Le cahier des charges place les appels audio/vidéo au jalon M6 et impose une étude de faisabilité avant développement : transport Wi‑Fi local, signalisation via canal autorisé, flux chiffrés, caméra/micro sous contrôle explicite, interruption propre par appel système, gestion du verrouillage et de la batterie. Aucun flux ne doit être enregistré ou envoyé à un tiers.

Un casque Bluetooth est un périphérique audio sélectionné par iOS ; il ne transporte pas la session réseau de l’appel. Prévoir des commandes compréhensibles (micro, caméra, changer la caméra, raccrocher), un état d’appel entrant et une fin propre. Ne pas prétendre qu’un appel fonctionne sans vérifier la couche réseau, audio, autorisations et route matérielle sur les appareils concernés.

## 4. Bluetooth et exécution en arrière-plan

Toute future implémentation native BLE doit utiliser Core Bluetooth et des rôles/appareils explicitement définis dans le protocole commun. La permission Bluetooth doit être expliquée dans l’`Info.plist` avec la clé d’usage correspondant aux API et aux versions ciblées. Les rôles d’arrière-plan `bluetooth-central` et `bluetooth-peripheral` ne sont à déclarer que si l’usage est réel, autorisé et justifié ; ces modes ne donnent pas une exécution illimitée.

Le scan en arrière-plan peut être moins fréquent et les événements de périphériques répétés peuvent être regroupés. La restauration d’état Core Bluetooth est une option explicite qui doit être mise en œuvre et testée. Les règles iOS évoluent ; consulter la documentation Apple en vigueur au moment du POC et tester arrêt forcé, mise en veille, réveil système et révocation des permissions. **Ne jamais promettre un maillage ou relais Bluetooth permanent en arrière-plan sur iPhone.** Expliquer honnêtement ce qui marche au premier plan et ce qui est limité en arrière-plan.

La proximité interplateforme BLE ne peut être déclarée fonctionnelle qu’après échange réel entre Android et iPhone, essais de reconnexion et mesure de batterie. Ne jamais demander à l’utilisateur de choisir des rôles techniques « central » ou « périphérique » ; l’application les négocie derrière l’interface.

## 5. UWB, confidentialité et sécurité

Nearby Interaction est une option de proximité précise uniquement lorsque les appareils compatibles et le contexte système le permettent. Vérifier la capacité au runtime, obtenir un consentement explicite et mutuel, limiter la session dans le temps et arrêter sur demande. L’accès et le comportement d’arrière-plan sont soumis aux règles du système. Si UWB manque, afficher un qualificatif sans chiffre de distance ; ne pas transformer la force BLE en mesure métrique.

Toute permission iOS doit correspondre à une fonction approuvée : Bluetooth, réseau local/Bonjour, caméra, microphone, photothèque, Face ID ou Nearby Interaction selon le besoin réel. Les descriptions d’usage doivent être claires et françaises. Les décisions restent réversibles et aucun identifiant, contenu, position exacte, clé ou image privée ne doit apparaître dans les logs.

Utiliser une bibliothèque cryptographique éprouvée et auditée ; aucune cryptographie maison. Préserver chiffrement Hive/gestion de clés existants, schéma versionné et migrations sauvegardées. Toute collecte, télémétrie, relais serveur ou mécanisme de compte exige une décision distincte.

## 6. Interface et accessibilité iOS

Préserver l’identité UpChat : interface française, accent bleu unique, thèmes clair/sombre/OLED et comportements existants validés. Utiliser les conventions Human Interface Guidelines sans copier les marques, textes ou actifs d’applications de référence. Prévoir des cibles tactiles d’au moins 44 pt, VoiceOver, tailles de texte accessibles, contraste, réduire les animations/transparences et états lisibles autrement que par la couleur.

Ne jamais rendre une action destructive (effacer l’historique, supprimer un pair, renouveler l’identité) irréversible sans confirmation adaptée. Ne pas promettre la protection contre toutes les captures d’écran sur iOS ; les limitations de la plateforme doivent rester explicites.

## 7. Validation et limites

Le workflow GitHub Actions contrôlé lors du M0 a compilé Android et Web, pas une cible iOS native. Une compilation Web verte n’est pas une preuve iOS. À chaque changement iOS, consigner la version et le modèle d’iPhone, la cible exacte (WebView ou app native), les permissions, les étapes, le résultat observé et les limitations. Les fonctions réseau, BLE, UWB, audio/vidéo et arrière-plan exigent des tests sur appareils physiques ; le simulateur ne suffit pas à prouver radio, routage ou batterie.

Exécuter et rapporter les tests disponibles (`flutter analyze`, `flutter test`, tests de widgets/intégration). Puis tester sur iPhone : démarrage, thèmes, conversation/historique, réseau Wi‑Fi local autorisé/refusé, Bluetooth devant et derrière, interruption par appel système, caméra/micro, UWB si modèle compatible, révocation d’autorisation, VoiceOver et navigation. Les contrôles non exécutés restent « non testés ». Le résultat CI vert du 19 novembre 2026 n’inclut pas ces vérifications manuelles.

## 8. Références officielles

- [Core Bluetooth Apple](https://developer.apple.com/documentation/corebluetooth)
- [Core Bluetooth en arrière-plan — modes, regroupement des scans et restauration](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)
- [Confidentialité du réseau local Apple — TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [Nearby Interaction Apple](https://developer.apple.com/documentation/nearbyinteraction)

Le cahier des charges détaillé a été fourni en pièce jointe de la tâche ; il n’est pas versionné dans ce dépôt.
