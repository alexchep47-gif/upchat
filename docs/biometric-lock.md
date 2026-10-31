# Verrou biométrique UpChat

Le verrou biométrique est facultatif. Il protège l’interface locale d’UpChat au démarrage et à chaque retour de l’application au premier plan. Il ne remplace pas Firebase Authentication et ne modifie ni le mode hors ligne, ni la découverte Nearby, ni le relais internet.

## Utilisation

Dans l’application mobile, ouvrir **Réglages > Confidentialité > Verrou biométrique**. L’activation demande immédiatement une empreinte ou une reconnaissance faciale déjà configurée dans le téléphone. Si cette vérification réussit, UpChat se verrouillera la prochaine fois que l’application passera en arrière-plan.

Pour désactiver la fonction, revenir au même interrupteur avant de quitter l’application. Si le téléphone n’a pas de biométrie inscrite, UpChat explique quoi faire dans les réglages du système et ne modifie pas l’option.

## Confidentialité et sécurité

UpChat ne lit, ne stocke et ne transmet jamais d’empreinte, de modèle facial ou de code de déverrouillage. Android et iOS réalisent la vérification ; l’application reçoit seulement un résultat de réussite ou d’échec.

Le verrou demande une biométrie uniquement : il ne propose pas le code PIN, le schéma ou le mot de passe de l’appareil comme solution de repli. Si la biométrie est temporairement verrouillée par le système ou supprimée après l’activation, il faut la rétablir dans les réglages du téléphone avant de pouvoir déverrouiller UpChat.

Le navigateur Web ne propose pas ce verrou. L’application reste utilisable sur le Web sans biométrie afin de ne pas bloquer la version publique.

## Pré-requis de build

Android utilise `local_auth`, `FlutterFragmentActivity`, la permission `USE_BIOMETRIC` et des thèmes AppCompat. Le projet cible Android 9 (API 28), au-dessus du minimum Android 24 du plugin. La CI iOS ajoute `NSFaceIDUsageDescription` au moment de générer le projet iOS.

## Vérification sur téléphone

1. Installer l’APK release produit par GitHub Actions sur un appareil avec verrou d’écran et biométrie inscrite.
2. Activer le verrou dans les réglages, puis accepter la demande système.
3. Ouvrir une discussion, envoyer l’application en arrière-plan, puis y revenir : l’écran de verrouillage UpChat doit masquer les discussions jusqu’à une biométrie valide.
4. Appuyer sur Annuler : l’écran reste verrouillé et propose de réessayer.
5. Tester un téléphone sans biométrie inscrite : l’activation doit échouer avec un message clair, sans bloquer UpChat.

## Sources techniques

- Package Flutter officiel `local_auth` : https://pub.dev/packages/local_auth
- Prérequis Android `FlutterFragmentActivity`, AppCompat et `USE_BIOMETRIC` : https://pub.dev/packages/local_auth_android
- Déclaration iOS `NSFaceIDUsageDescription` : https://pub.dev/packages/local_auth_darwin
