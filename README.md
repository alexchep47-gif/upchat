# UpChat

**Messagerie P2P 100 % offline** — Bluetooth + WiFi Direct (Nearby Connections)

Style WhatsApp, fonctionne sans aucune connexion internet (portée radio locale).

## Créé par

**NEMMEGNE CHEPING ALEXANDRE MERVIN**  
Nationalité : **Camerounaise**

## Fonctionnalités

- Messagerie 1-à-1 offline (découverte automatique des appareils proches)
- Groupes offline
- Médias (images, vidéos) avec transfert binaire
- Stories offline (24 h)
- Mode mesh (relais 1 hop)
- Accusés de réception / lecture
- Indicateur « en train d'écrire »
- Chiffrement local (Hive + AES)
- Thème clair / sombre OLED
- Interface en français

## Limites importantes

- **Portée** : quelques dizaines de mètres (Bluetooth / WiFi Direct).  
  Une portée de centaines de km est **impossible** sans internet ou réseau cellulaire.
- **Android uniquement** pour le vrai P2P offline (Nearby Connections = Google Play Services).
- **Android ↔ iPhone** et **iPhone ↔ iPhone** offline type WhatsApp ne sont pas supportés par les APIs natives de façon interopérable. Un mode internet serait nécessaire pour le cross-plateforme.

## Compilation

L'APK est généré automatiquement via **GitHub Actions** à chaque push sur `main`.

1. Onglet **Actions** du dépôt
2. Workflow **Build APK**
3. Télécharger l'artefact `upchat-apk`
4. Installer sur téléphone Android (avec Google Play Services)

## Licence

Projet personnel — **NEMMEGNE CHEPING ALEXANDRE MERVIN** (Cameroun)
