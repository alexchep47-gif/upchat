# Plan UpChat — fiabilisation et livraison

## Périmètre
Réparer l’application Flutter et son relais de signalisation existant, produire un APK Android universel compatible Android 9+, et publier un site responsive UpChat sur Vercel sans mention de GitHub.

## Architecture retenue
- **Flutter mobile/web** : routes centralisées, thème Telegram/UpChat unique, démarrage fluide, proximité Nearby, mode internet résilient.
- **Relais backend** : `upchat-signal` sur Render + PostgreSQL, conservé comme source de vérité de production car sa santé est actuellement OK. Les endpoints d’enregistrement, lookup, présence, messages et inbox restent contractuels.
- **Livraison Android** : APK universel non scindé comme artefact principal, avec APK arm64/armeabi-v7a/x86_64 en artefacts secondaires.
- **Site** : site statique responsive hébergé par le dépôt `upchat-web`, avec téléchargement local `/downloads/UpChat-universal.apk` alimenté par le workflow.

## Design
Trois directions considérées : Telegram calme et fonctionnel (0,06), WhatsApp chaleureux et dense (0,07), verre néon futuriste (0,04). Choix : **Telegram calme et fonctionnel**.

Le système utilise une signature bleu UpChat (`#2AABEE`) avec surfaces bleues-grisées, contrastes accessibles, rayons modérés et hiérarchie nette. Les écrans privilégient les listes à sections, les actions directes et des transitions courtes. Le logo conserve le U propriétaire d’UpChat dans une pastille bleue, sans emoji système. La voix est directe et rassurante : « Discute sans réseau. » et « Tes messages restent à portée de ton appareil. »

## Modules à modifier
- `lib/core/routes` : supprimer les chemins ambigus et fournir un écran Appareils connectés.
- `lib/core/theme`, `lib/main.dart`, ressources Android : uniformiser le design et le splash U.
- `lib/data/services/internet_service.dart` : santé, reconnexion, erreurs et lookup résilients.
- `lib/features/settings` et `lib/features/devices` : réglages inspirés Telegram et état réel des appareils/session.
- `.github/workflows/build.yml` : APK universel Android 9+ et copie vers le site.
- `upchat-signal` : santé et schéma PostgreSQL conservés, avec migrations/index non destructifs si nécessaires.
- `upchat-web` : site vitrine responsive et route de téléchargement locale.
