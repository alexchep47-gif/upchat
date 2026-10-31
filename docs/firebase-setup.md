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

Le fichier `firebase_options.dart` doit contenir les mêmes `projectId`, `appId`, `apiKey` et `messagingSenderId` que les applications Firebase. Le build Web appelle `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` ; Android et iOS lisent leur configuration native injectée. L’initialisation Firebase reste hors du chemin critique de démarrage afin que le mode hors ligne s’ouvre sans réseau.

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

## 7. Checklist Android depuis GitHub et Firebase

Les erreurs Google `ApiException: 10` et Firebase `CONFIGURATION_NOT_FOUND` sont des erreurs de configuration de console ou de secrets. Elles ne peuvent pas être résolues en fabriquant un fichier `google-services.json` dans le dépôt.

1. Dans GitHub, ouvrir **Actions > Generate UpChat signing keystore > Run workflow** après avoir créé `KEYSTORE_PASSWORD` et `KEY_ALIAS` dans **Settings > Secrets and variables > Actions**. Le workflow affiche uniquement SHA-1 et SHA-256 puis conserve l’artefact de clé pendant un jour.
2. Télécharger immédiatement l’artefact `upchat-release-keystore-private`, le conserver dans un emplacement privé, puis l’encoder en Base64 depuis un terminal de confiance : `base64 -w0 upchat-release.jks`. Enregistrer le résultat dans `KEYSTORE_BASE64`. Ne jamais commiter la clé ni publier son contenu.
3. Dans **Firebase console > Project settings > Your apps > Android**, vérifier que le package est exactement `com.upchat.app`, ajouter les empreintes SHA-1 et SHA-256 affichées par le workflow, puis télécharger à nouveau `google-services.json`.
4. Encoder ce nouveau fichier et l’ajouter comme `GOOGLE_SERVICES_JSON_BASE64` (ou conserver le nom historique `FIREBASE_ANDROID_JSON_BASE64`). Le workflow accepte les deux noms.
5. Dans **Firebase console > Authentication > Sign-in method**, démarrer Authentication si nécessaire, activer **Email/Password** et **Google**, puis renseigner l’adresse e-mail d’assistance.
6. Dans **Google Cloud console > APIs & Services**, vérifier que le client OAuth Android utilise `com.upchat.app` et la même empreinte SHA-1. Copier l’ID du client OAuth de type **Web application** dans le secret GitHub `GOOGLE_SERVER_CLIENT_ID`.
7. Vérifier que l’API **Identity Toolkit API** est activée et que les restrictions de clé API autorisent l’application Android avec son package et son SHA-1. Si l’écran de consentement OAuth est en test, ajouter le compte de test.
8. Relancer **Build Android and Web**, installer le nouvel APK release, désinstaller l’ancienne version si elle a une autre signature, puis retester Google et e-mail.

La CI accepte également `UPCHAT_KEYSTORE_BASE64`, `UPCHAT_KEYSTORE_PASSWORD`, `UPCHAT_KEY_ALIAS` et `UPCHAT_KEY_PASSWORD` pour conserver la compatibilité avec les secrets déjà configurés. Elle transmet `GOOGLE_SERVER_CLIENT_ID` et, si besoin, `UPCHAT_SERVER_URL` via `--dart-define` : ces valeurs ne sont pas commitées dans le code.
