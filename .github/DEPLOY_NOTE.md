# Deploy

- **APK** : artifact `upchat-apk` (workflow Build Android and Web)
- **Web (GitHub Pages)** : désactivé dans le job actuel (focus Vercel)
- **Web (Vercel https://upchat-web.vercel.app/app/)** : nécessite le secret `GH_PAT` sur le repo `upchat` pour pousser dans `upchat-web` sous `/app`

## Secret GH_PAT

1. Créer un Personal Access Token (classic) avec scope `repo`
2. Settings du repo `upchat` → Secrets and variables → Actions → New repository secret
3. Nom : `GH_PAT` — Valeur : le token

Même secret doit déjà exister sur `calc-for-all` pour le déploiement Vercel de Calc For All.
