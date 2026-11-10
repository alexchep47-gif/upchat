# Mise à jour mobile UpChat

UpChat utilise un manifeste JSON public hébergé dans le dépôt GitHub. L’application ne demande aucune permission supplémentaire et ne télécharge ni n’installe silencieusement un APK ou une IPA.

Le chemin par défaut est `update-manifest.json` sur la branche `main`. Il peut être remplacé au build avec `--dart-define=UPCHAT_UPDATE_MANIFEST_URL=https://...`.

## Format du manifeste

```json
{
  "latestVersion": "1.3.3",
  "minimumVersion": "1.3.2",
  "releaseUrl": "https://github.com/alexchep47-gif/upchat/releases/tag/v1.3.3",
  "androidUrl": "https://github.com/alexchep47-gif/upchat/releases/download/v1.3.3/upchat-android.apk",
  "iosUrl": "https://github.com/alexchep47-gif/upchat/releases/tag/v1.3.3",
  "notes": "Correctifs de sécurité et de fiabilité."
}
```

`latestVersion` déclenche l’affichage d’une nouvelle version. `minimumVersion` permet de rendre une version obligatoire dans l’interface de mise à jour. Les URL doivent être en HTTPS. Android ouvre la page ou l’APK de release dans le navigateur/gestionnaire du téléphone ; iOS ouvre la page de distribution autorisée, car une IPA ne peut pas être remplacée silencieusement par une application tierce.

## Publication

1. Incrémenter `version` et `versionCode` via `pubspec.yaml`.
2. Produire et vérifier l’APK/IPA avec GitHub Actions.
3. Publier les artefacts dans une GitHub Release versionnée.
4. Modifier `update-manifest.json` avec les URL exactes de cette release.
5. Fusionner le manifeste sur `main` après vérification des liens.
6. Tester dans **Réglages → Aide → Rechercher une mise à jour**.

Le contrôle est manuel depuis les réglages : il n’y a donc pas de requêtes réseau répétées ni de sollicitation de permission au démarrage. Si le manifeste est absent, invalide ou inaccessible, l’application continue normalement en mode hors ligne.
