# Deploy

- **APK** : artifact `upchat-apk` (workflow Build Android and Web)
- **Web (GitHub Pages)** : https://alexchep47-gif.github.io/upchat/
- **Web (Vercel public)** : https://upchat-web-pi.vercel.app/app/
- **Vercel (équipe CMR SCHOOL)** : le domaine public stable est `upchat-web-pi.vercel.app`; les domaines `*-cmr-school.vercel.app` restent protégés par l’authentification Vercel.
- Le workflow pousse le build dans `upchat-web` sous `/app`; le secret `GH_PAT` doit être configuré sur le repo `upchat`.

## Secret GH_PAT

1. Créer un Personal Access Token (classic) avec scope `repo`
2. Settings du repo `upchat` → Secrets and variables → Actions → New repository secret
3. Nom : `GH_PAT` — Valeur : le token

Même secret doit déjà exister sur `calc-for-all` pour le déploiement Vercel de Calc For All.
