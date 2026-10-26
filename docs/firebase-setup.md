# Configuration Firebase complète d’UpChat

La connexion distante est facultative : si Firebase n’est pas configuré, UpChat reste utilisable en proximité et en local. Pour activer l’authentification distante et la vérification serveur, les quatre couches suivantes doivent être présentes.

## 1. Console Firebase

Créer un projet Firebase puis ajouter :

- Android : package `com.upchat.app` ;
- iOS : bundle ID `com.upchat.app` ;
- Web : l’application Web utilisée par le build Flutter.

Dans **Authentication > Sign-in method**, activer au minimum E-mail/Mot de passe et Google. Apple ne doit être activé qu’après configuration du compte Apple Developer et de la capacité Sign in with Apple.

Pour une identification par numéro, activer également **Phone**. Google et E-mail ne prouvent pas la possession d’un numéro de téléphone.

## 2. Secrets GitHub du dépôt `alexchep47-gif/upchat`

Créer les secrets suivants depuis un ordinateur de confiance ou depuis un terminal mobile. Les valeurs sont encodées en base64 et ne sont jamais commitées.

```sh
base64 -w 0 google-services.json
base64 -w 0 GoogleService-Info.plist
base64 -w 0 lib/firebase_options.dart
base64 -w 0 release-keystore.jks
```

Secrets attendus :

| Secret | Contenu |
|---|---|
| `FIREBASE_ANDROID_JSON_BASE64` | `google-services.json` de l’app Android |
| `FIREBASE_IOS_PLIST_BASE64` | `GoogleService-Info.plist` de l’app iOS |
| `FIREBASE_OPTIONS_DART_BASE64` | fichier `firebase_options.dart` généré par FlutterFire |
| `UPCHAT_KEYSTORE_BASE64` | keystore de release fixe |
| `UPCHAT_KEYSTORE_PASSWORD` | mot de passe du keystore |
| `UPCHAT_KEY_ALIAS` | alias de la clé |
| `UPCHAT_KEY_PASSWORD` | mot de passe de la clé |
| `GH_PAT` | token GitHub limité aux dépôts nécessaires pour publier le site et déclencher Pages |

Le fichier `firebase_options.dart` doit contenir les mêmes `projectId`, `appId`, `apiKey` et `messagingSenderId` que les applications Firebase. Le code appelle `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` avant `runApp`.

## 3. Android

Ajouter les empreintes SHA-1 et SHA-256 de la **keystore de release fixe** dans les réglages de l’application Android Firebase. La CI utilise cette keystore quand `UPCHAT_KEYSTORE_BASE64` est présent ; sinon elle utilise uniquement une signature debug de secours.

Le plugin Gradle `com.google.gms.google-services` est déjà déclaré et appliqué uniquement lorsque `android/app/google-services.json` a été injecté.

## 4. iOS

La CI génère le projet iOS, injecte `GoogleService-Info.plist`, puis l’ajoute explicitement aux ressources `Runner.xcodeproj`. Elle extrait aussi `REVERSED_CLIENT_ID` et ajoute le schéma d’URL dans `Runner/Info.plist`.

Le build iOS exige une version minimale iOS compatible avec les versions Firebase choisies. Le bouton Apple est masqué tant que le parcours Apple et sa capacité développeur ne sont pas réellement configurés.

## 5. Serveur de signalisation

Le serveur utilise Firebase Admin lorsque `FIREBASE_SERVICE_ACCOUNT_JSON` ou `GOOGLE_APPLICATION_CREDENTIALS` est défini. Il vérifie alors chaque `Authorization: Bearer <Firebase ID token>` avec `verifyIdToken`. La route `/api/health` indique `auth: firebase-admin` lorsque ce mode est actif.

Variables du serveur :

- `FIREBASE_SERVICE_ACCOUNT_JSON` : JSON du compte de service Firebase, stocké uniquement dans l’environnement Render/Vercel ;
- `GOOGLE_APPLICATION_CREDENTIALS` : chemin vers un compte de service lorsque la plateforme fournit le fichier ;
- `FIREBASE_PROJECT_ID` : identifiant du projet ;
- `DATABASE_URL` : base PostgreSQL de production ;
- `UPCHAT_ALLOWED_ORIGINS` : origines Web autorisées.

Sans ces variables, le serveur reste en mode de compatibilité `legacy-device-token` afin de ne pas casser une installation existante. Ce mode doit être désactivé en production après migration des utilisateurs.

## 6. Vérification de numéro

La recherche par numéro ne doit être considérée comme vérifiée qu’après authentification Firebase et, si nécessaire, Phone Auth par SMS. Un contact créé hors ligne reste utilisable localement avec un statut « À vérifier » ; l’échec réseau ne doit jamais bloquer les conversations de proximité.
