# Configuration Firebase officielle

Les fichiers Firebase ne doivent pas être fabriqués ni commités avec de fausses valeurs. Depuis la console Firebase du projet UpChat, télécharger :

- `google-services.json` pour Android ;
- `GoogleService-Info.plist` pour iOS.

Dans GitHub, créer les secrets Actions suivants en Base64 :

```sh
base64 -w0 google-services.json
base64 -w0 GoogleService-Info.plist
```

- `FIREBASE_ANDROID_JSON_BASE64`
- `FIREBASE_IOS_PLIST_BASE64`

Le workflow les écrit uniquement pendant le build, dans `android/app/` et `ios/Runner/`. Ils ne sont jamais poussés dans Git. Tant que ces secrets ne sont pas présents, l’application reste compilable et utilisable hors ligne, mais l’authentification Firebase distante reste désactivée.
