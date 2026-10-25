# Architecture backend et sécurité UpChat

## Décision d’architecture

UpChat doit séparer trois responsabilités : le stockage local, le transport réseau et le contenu chiffré. Le serveur ne doit jamais être nécessaire pour lire une conversation locale, et le relais internet doit transporter des enveloppes opaques plutôt que du texte clair.

Le modèle retenu est hybride : fonctionnement local prioritaire, relais internet optionnel, file d’envoi persistante et média traité séparément des messages. La base de données distante ne doit pas être utilisée comme une copie exploitable des messages en clair.

Il ne faut pas reproduire aveuglément un seul produit. WhatsApp utilise le chiffrement de bout en bout comme fondation et complète la vérification par un répertoire de clés auditable et une transparence des clés [1]. Telegram distingue explicitement ses « Cloud Chats », chiffrés client-serveur, de ses « Secret Chats », chiffrés de bout en bout [2]. Pour UpChat, le mode internet doit viser le modèle E2EE par défaut, sans présenter un simple TLS comme du chiffrement de bout en bout.

## État livré dans cette itération

Les identifiants locaux, le nom, la bio, la photo et le numéro de téléphone sont maintenant migrés dans une boîte Hive séparée chiffrée avec AES. La clé de boîte est conservée dans `flutter_secure_storage`. La génération de cette clé utilise désormais `Random.secure()` ; la génération précédente, basée sur l’horloge, n’était pas acceptable pour une clé cryptographique.

Les chemins de fichiers locaux ne sont plus envoyés au relais internet. Les erreurs HTTP ne sont plus considérées comme des transmissions réussies, les messages restent dans la file d’attente persistante et les journaux ne contiennent plus le corps complet des réponses ni les identifiants de destinataires.

Cette itération ne prétend pas encore fournir un protocole E2EE complet. Le serveur de signalisation actuel n’est pas présent dans ce dépôt ; il est référencé par `AppConstants.signalingBaseUrl`. Il doit donc être durci et déployé séparément avant de présenter le mode internet comme production-ready.

## Couches proposées

### Client

Le client conserve les messages dans une boîte locale chiffrée. Chaque message réseau doit être une enveloppe versionnée contenant un identifiant unique, une conversation, un compteur anti-rejeu, un horodatage borné, l’identifiant de clé et un ciphertext AEAD. Les clés privées doivent rester dans le stockage sécurisé du terminal.

Les clés d’identité doivent être accompagnées d’une empreinte vérifiable et d’un écran de vérification QR ou code court. Une modification de clé doit être visible et invalider l’état « vérifié ». Cette vérification manuelle complète la transparence de clés ; elle ne doit pas être remplacée par une simple confiance dans le serveur.

### API gateway

Le relais doit imposer TLS, une taille maximale de requête, une validation stricte de schéma, une authentification de session courte et une limitation par compte, adresse et appareil. Les endpoints publics doivent répondre avec des erreurs génériques afin de ne pas révéler si un numéro existe, sauf dans un flux d’autorisation explicite.

Les endpoints minimum sont :

- `POST /v1/auth/register-device` pour enregistrer une clé d’identité publique et un appareil ;
- `POST /v1/auth/refresh` pour renouveler une session courte ;
- `GET /v1/keys/{userId}` pour récupérer des clés publiques avec preuve de version ;
- `POST /v1/messages` pour relayer une enveloppe chiffrée idempotente ;
- `GET /v1/messages/sync?cursor=...` pour synchroniser des enveloppes sans texte clair ;
- `POST /v1/receipts` pour les accusés de réception minimisés ;
- `POST /v1/media/init` et `POST /v1/media/complete` pour séparer les médias du texte ;
- `GET /v1/health` pour la supervision, sans données utilisateur.

### Données serveur

Une base relationnelle convient au registre des comptes, appareils, clés publiques, sessions, curseurs et états d’idempotence. Un stockage objet privé convient aux médias chiffrés. Une file durable convient à la distribution et aux nouvelles tentatives. Les index ne doivent pas exposer le contenu des messages.

Le serveur peut conserver un pointeur de livraison, un hash d’enveloppe, un curseur et des dates d’expiration. Il ne doit pas conserver le plaintext, les chemins locaux, le carnet d’adresses complet, ni une présence plus précise que nécessaire. Les journaux doivent utiliser des identifiants tronqués ou des identifiants de corrélation éphémères.

### Enveloppe et anti-rejeu

Le format doit être versionné dès le départ :

```json
{
  "version": 1,
  "messageId": "uuid-v4",
  "conversationId": "opaque-id",
  "senderDeviceId": "opaque-id",
  "keyId": "public-key-version",
  "counter": 42,
  "createdAt": "2026-01-01T00:00:00Z",
  "ciphertext": "base64url",
  "nonce": "base64url",
  "associatedDataHash": "base64url"
}
```

`messageId` doit être unique et faire l’objet d’une contrainte d’idempotence. Un compteur déjà consommé ne doit pas être accepté deux fois. Les horloges clientes ne doivent pas décider seules de l’expiration ; le serveur applique une fenêtre tolérée et le client applique aussi une limite locale.

## Protocole cryptographique cible

Il ne faut pas coder un nouveau protocole de messagerie à la main. Le socle cible est un protocole audité de type Signal : accord de clés initial, clés de session, ratchet symétrique par message, ratchet Diffie-Hellman, clés supprimées après usage et prise en charge des messages hors ordre. Le Double Ratchet documente précisément ces propriétés de forward security, de récupération après compromission et de gestion des messages hors ordre [3].

Les étapes de production sont :

1. sélectionner une bibliothèque Signal maintenue et compatible Flutter/Web ou isoler la cryptographie dans un service natif audité ;
2. définir l’identité multi-appareils et le registre de clés publiques ;
3. implémenter les pré-clés, le prekey bundle et la rotation ;
4. intégrer la vérification QR/code et l’alerte de changement de clé ;
5. tester les rejeux, pertes, doublons, appareils réinstallés et messages hors ordre ;
6. faire auditer le protocole et le serveur avant de promettre une sécurité équivalente à une messagerie mature.

AES-GCM ou ChaCha20-Poly1305 doit être utilisé comme AEAD dans une bibliothèque éprouvée. Le nonce ne doit jamais être réutilisé avec la même clé. Les clés de message et les anciennes clés de chaîne doivent être supprimées dès que le protocole le permet.

## Règles de confidentialité

Le numéro de téléphone doit être normalisé côté client, transmis uniquement au flux d’inscription ou de recherche autorisé, puis protégé contre l’énumération par des réponses uniformes et du rate limiting. La présence doit être arrondie et expirer automatiquement. Les médias doivent être chiffrés côté client avant upload, avec des URLs d’objet courtes et non réutilisables.

Les sauvegardes doivent être opt-in, chiffrées avec une clé contrôlée par l’utilisateur et séparées des clés de session. La suppression doit prévoir une purge locale, une révocation d’appareil, une suppression des enveloppes en attente et une expiration des médias temporaires. Les analytics ne doivent pas recevoir le contenu, les contacts ou les clés.

## Ce qui reste à faire côté serveur

Le dépôt actuel contient le client Flutter et un service de signalisation référencé à distance, mais pas l’implémentation complète de cette API. Avant la mise en production, il faut donc créer ou auditer le service `upchat-signal` avec validation de schéma, authentification d’appareil, registre de clés, idempotence, rate limiting, stockage chiffré des médias, rotation des secrets, sauvegardes, alertes et tests de pénétration.

La cible est « privacy by design » et non une promesse marketing d’« ultra-sécurité ». Une sécurité comparable à WhatsApp ou Telegram demande un protocole E2EE audité, une gestion multi-appareils complète, une infrastructure de clés et un audit indépendant.

## Références

[1]: https://engineering.fb.com/2023/04/13/security/whatsapp-key-transparency/ "Deploying key transparency at WhatsApp"
[2]: https://core.telegram.org/techfaq "Telegram FAQ for the Technically Inclined"
[3]: https://signal.org/docs/specifications/doubleratchet/ "Signal Double Ratchet specification"
