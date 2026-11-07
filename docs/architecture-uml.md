# Architecture UpChat — schéma UML / composants

## Vue composants (client Flutter)

```mermaid
flowchart TB
  subgraph UI["Features UI"]
    ON[OnboardingScreen]
    AUTH[LoginScreen]
    HOME[ConversationsListScreen]
    CHAT[ChatScreen]
    PROF[ProfileScreen]
    SET[SettingsScreen]
    STORY[Stories]
  end

  subgraph PROV["Providers"]
    CP[ChatProvider]
    NP[NearbyProvider]
    PP[ProfileProvider]
    ConnP[ConnectivityProvider]
    SP[SettingsProvider]
    TP[ThemeProvider]
    StP[StoriesProvider]
  end

  subgraph SVC["Services"]
    SS[StorageService Hive]
    NS[NearbyService]
    MS[MeshService]
    IS[InternetService]
    FA[FirebaseAuthService]
    OSS[OfflineSyncService]
  end

  subgraph EXT["Externes"]
    BT["Bluetooth / Wi‑Fi Direct\nGoogle Play Services"]
    FB[Firebase Auth]
    SIG["upchat-signal\nRender + Postgres"]
  end

  UI --> PROV
  PROV --> SVC
  NS --> BT
  MS --> NS
  IS --> SIG
  FA --> FB
  CP --> SS
  CP --> NS
  CP --> IS
  SS --> Hive[(Hive local)]
```

## Domaine (modèles)

```mermaid
classDiagram
  class UserModel {
    +String id
    +String name
    +String? phone
    +String? photoPath
  }
  class ConversationModel {
    +String id
    +String title
    +bool isGroup
    +int unreadCount
    +String? lastMessage
  }
  class MessageModel {
    +String id
    +String conversationId
    +String senderId
    +String text
    +DateTime createdAt
    +bool isMine
  }
  class GroupModel {
    +String id
    +String name
    +List~String~ memberIds
  }
  class StoryModel {
    +String id
    +String authorId
    +DateTime expiresAt
  }
  ConversationModel "1" --> "*" MessageModel
  GroupModel --> ConversationModel
  UserModel --> ConversationModel : peer
  UserModel --> StoryModel
```

## Pipeline envoi message

```mermaid
sequenceDiagram
  participant U as UI Chat
  participant C as ChatProvider
  participant S as StorageService
  participant N as NearbyService
  participant I as InternetService
  participant R as upchat-signal

  U->>C: send(text)
  C->>S: persist local
  C->>N: try P2P
  alt voisin proche
    N-->>C: delivered nearby
  else pas de voisin + internet ON
    C->>I: send envelope
    I->>R: POST /api/message
    R-->>I: accepted
  end
```

## Déploiement

| Couche | Hébergement |
|--------|-------------|
| App Android/iOS | GitHub Actions → APK / IPA sideload |
| Web app | GitHub Pages / workflow web |
| Site vitrine | upchat-web (Vercel) |
| Signalisation | **upchat-signal** sur **Render** + Postgres |
| Auth optionnelle | Firebase |
