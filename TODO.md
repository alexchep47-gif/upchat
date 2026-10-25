# UpChat — livrables

## 1. Corriger la navigation et les appareils connectés
- [ ] Aucun onglet ne doit renvoyer vers un chemin ambigu ou un écran placeholder.
- [ ] L’écran « Appareils connectés » doit afficher l’état réel de la proximité, les appareils découverts/connectés et l’état du relais internet.

## 2. Fiabiliser le lookup par numéro et le backend
- [ ] La saisie d’un numéro doit normaliser le format, vérifier la session, tenter la reconnexion et retourner une erreur utile plutôt que « serveur indisponible » lorsque le relais répond.
- [ ] Le frontend et le backend doivent conserver un contrat cohérent pour register, lookup, presence, message et inbox.
- [ ] La base PostgreSQL doit conserver les index nécessaires et ne recevoir que des changements non destructifs.

## 3. Uniformiser l’identité visuelle
- [ ] Les couleurs de l’application doivent être cohérentes entre clair, sombre, réglages, discussions, états et chargement.
- [ ] Le chargement doit afficher le logo U UpChat et une animation courte, sans branding Flutter.
- [ ] Les réglages doivent se rapprocher de la structure et de la densité de Telegram.

## 4. Livrer Android 9+
- [ ] Le build Android doit cibler Android 9 minimum et produire un APK universel non arm64 comme artefact principal.
- [ ] Les artefacts ABI séparés restent disponibles pour les appareils compatibles.
- [ ] Le workflow doit publier le dernier APK dans un lien stable du site.

## 5. Livrer le site responsive
- [ ] Le site doit être responsive, soigné et sans mention de GitHub ni lien vers le dépôt.
- [ ] Le site doit proposer le téléchargement du dernier APK via une route locale et être déployé par le projet Vercel existant.
