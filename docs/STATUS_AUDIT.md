# État UpChat — réponse à l’audit (2026-10-28)

## Correctif appliqué : démarrage hors ligne

**Avant (audit)** : `await FirebaseAuthService.initialize()` dans le chemin critique de boot → risque de blocage / écran d’erreur si Firebase indisponible.

**Après** (`lib/main.dart`) :
1. **Chemin critique** = Hive + `StorageService` uniquement.
2. Firebase démarre en **arrière-plan** (`unawaited`), timeout 8 s, erreurs ignorées.
3. Écran d’erreur (stockage local seulement) propose **« Continuer hors ligne »** en plus de Réessayer.

→ L’app **ne dépend plus de Firebase pour s’ouvrir**. Conversations locales / Nearby restent accessibles sans réseau.

## Points toujours « non confirmés » (honnêteté)

| Point | Statut |
|-------|--------|
| Builds CI Android / Web / IPA | Signalés OK en CI — ≠ test utilisateur réel |
| Google Sign-In de bout en bout | Non testé sur appareil ici (SHA-1 + `GOOGLE_SERVER_CLIENT_ID` côté projet) |
| Relais messages internet (`upchat-signal`) | Code présent ; dispo serveur non monitorée en live |
| IPA | `--no-codesign` / Sideloadly — **pas** App Store |
| Signature Android release | Dépend des secrets keystore dans Actions |
| Tests sur téléphone réel | Non effectués par l’agent |

## Ce que l’on peut affirmer côté code

- Mode offline **conçu** pour fonctionner sans Firebase (stockage Hive, Nearby).
- Auth Google / email = **optionnelle**.
- Page statut site web : garder les libellés « non confirmé » pour les fonctions non testées sur appareil.

## Recommandations avant usage public

1. Installer l’APK CI sur 2 téléphones Android et valider Nearby + chat local.
2. Activer mode internet + vérifier `https://upchat-signal.onrender.com` (health).
3. Configurer SHA-1 + client OAuth Web pour Google.
4. iOS : sideload uniquement tant que pas de compte Apple Developer payant.
