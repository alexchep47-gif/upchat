# UpChat

**Messagerie P2P 100 % offline** — Bluetooth + WiFi Direct (Nearby Connections)

Style WhatsApp, fonctionne sans aucune connexion internet.

## Fonctionnalités

- Messagerie 1-à-1 offline (découverte automatique des appareils proches)
- Groupes offline
- Médias complets (images, vidéos, notes vocales, fichiers)
- Stories offline (diffusion automatique aux contacts à portée, 24 h)
- Chiffrement local des messages (Hive + AES)
- Thème clair / sombre OLED
- Interface en français

## Compilation

L'APK est généré automatiquement via **GitHub Actions** à chaque push sur `main`.

1. Va dans l'onglet **Actions** du dépôt
2. Attends la fin du workflow **Build APK**
3. Télécharge l'artefact `upchat-apk`
4. Installe l'APK sur ton téléphone Android

> **Note** : Nearby Connections nécessite les **Google Play Services**. Ne fonctionne pas sur certains appareils Huawei sans GMS.

## Architecture

Voir la structure dans `lib/`.

## Licence

Projet personnel — Alex Chep
