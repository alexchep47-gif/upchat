---
name: upchat-telegram-design
description: >
  Design et review UI/UX d'UpChat (Flutter, Android + iOS) dans l'esprit
  Telegram calme et fonctionnel, avec contraintes HIG iOS adaptées au mobile
  cross-platform. Utiliser pour listes de chats, écran discussion, onboarding,
  glass, thèmes clair/sombre/OLED, safe areas, accessibilité. Ne pas utiliser
  pour les bots Telegram API (voir références upstream bot).
---

# UpChat — Design Telegram + HIG (Flutter)

## Produit

- **App** : UpChat — messagerie offline-first (Nearby / P2P) + internet optionnel
- **Direction** (plan.md) : **Telegram calme et fonctionnel** (pas WhatsApp dense, pas néon futuriste)
- **Signature** : bleu `#2AABEE` — **aucun vert** dans l'UI (coches, badges, online)
- **Voix** : directe et rassurante — « Discute sans réseau. » / « Tes messages restent à portée de ton appareil. »
- **Auteur** : NEMMEGNE CHEPING ALEXANDRE MERVIN (Cameroun)

## Quand activer ce skill

- Refonte ou review d'écrans chat, home, onboarding, réglages, profil
- Glassmorphism, bulles, header flottant, barre de saisie
- Thèmes clair / sombre / OLED, contrastes, safe areas iOS
- Alignement avec `lib/core/theme/` (`app_colors.dart`, `app_theme.dart`, `app_glass.dart`)

## Principes (synthèse Telegram × HIG)

### Clarté (HIG Clarity + Telegram)
- Texte lisible à toutes tailles ; hiérarchie nette (titre > sous-titre > méta)
- Une action primaire évidente par écran
- États vides / erreur / hors ligne **en mots**, pas seulement en couleur

### Déférence (HIG Deference)
- Le contenu (messages, listes) occupe l'écran ; chrome discret
- Translucidité / blur **suggèrent** la profondeur sans cacher le texte
- Max **3** `BackdropFilter` permanents ; si `lowDataMode` → surfaces opaques

### Profondeur (HIG Depth + Telegram)
- Couches : fond chat → bulles → header verre → input flottant
- Transitions courtes (180–280 ms), pas de motion gratuite
- Respecter `viewPadding` / `viewInsets` (clavier, home indicator)

### Priorité information (Telegram)
- Listes à sections, actions directes
- Non-lus et présence **lisibles** (badge + libellé si besoin)
- Pas de panneau « Actions rapides » gadget dans le chat

## Tokens UpChat (source de vérité code)

Fichier : `lib/core/theme/app_colors.dart`

| Rôle | Valeur |
|------|--------|
| Primary / accent | `#2AABEE` |
| Primary dark | `#229ED9` |
| Fond clair | `#FFFFFF` |
| Fond sombre | `#0E1621` |
| Surface sombre | `#17212B` |
| Surface élevée sombre | `#232E3C` |
| Bulle moi (clair) | `#DFF3FF` |
| Bulle moi (sombre) | `#2B5278` |
| Bulle autre (sombre) | `#182533` |
| Online / unread | `#2AABEE` (bleu, jamais vert) |
| OLED | `#000000` |
| Glass light / dark | `0xCCFFFFFF` / `0x9917212B` |

**Interdit** : introduire un vert type WhatsApp pour les accusés de lecture ou le statut en ligne.

## Patterns d'écrans

### Onboarding
1. Accueil dark type « LIVE » + pastilles features + CTA dégradé bleu→violet acceptable **uniquement** sur le premier écran marketing
2. Permissions réelles (états téléphone, pas de faux succès)
3. Profil (nom + téléphone optionnel)

### Home / listes
- Onglets : Tous / Personnel / Groupes / Proches
- Tuile : avatar, titre, aperçu, heure, badge non-lus, point présence si proche
- Bannière connectivité honnête (internet / proximité / local)

### Chat
- Header flottant verre (retour, avatar, nom, statut)
- Liste inversée, séparateurs de date
- Bulles avec queue discrète ; timestamps + ticks **bleus**
- Input flottant : attache / texte / envoi ; gère `viewInsets`
- Emojis système colorés OK ; pas d'emoji dans le logo app

### Réglages / profil
- Groupes de listes type iOS inset (inspiré HIG Lists)
- Changer thème, police, économie data (coupe le blur), effacer données

## Contraintes iOS (HIG adaptées Flutter)

- **Safe areas** : notch / Dynamic Island / home indicator — jamais coller contrôles sous le system UI
- **Cibles tactiles** ≥ 44 pt
- **Contraste** : viser WCAG AA (4.5:1 texte normal)
- **Dynamic Type** : respecter `MediaQuery.textScaler` / réglage police app
- **Reduce motion** : si l'OS le demande, éviter les gros springs
- **Dark mode** : tester clair + sombre + OLED ; pas de noir pur sauf mode OLED explicite
- IPA : sideload possible ; ne pas promettre App Store sans signature pro

## Grille & motion

- Grille de base **8 pt** ; marges écran ~16–20
- Rayons modérés (12–28), pas de « squircles » excessifs partout
- Animations : 0.2–0.3 s actions UI ; 0.3–0.5 s changements d'écran

## Barre qualité (acceptance)

- [ ] L'utilisateur comprend quoi faire ensuite sans tutoriel
- [ ] Offline : UI reste utilisable ; messages d'état clairs
- [ ] Accent uniquement bleu UpChat ; pas de vert parasite
- [ ] ≤ 3 blurs permanents ; fallback opaque low-data
- [ ] Clavier ne cache pas le champ de saisie
- [ ] Header / input ne entrent pas sous les barres système
- [ ] Light + dark + OLED vérifiés sur les écrans touchés
- [ ] Aucune promesse visuelle non supportée par le code (ex. portée 300 km)

## Fichiers à modifier en priorité

- `lib/core/theme/app_colors.dart`, `app_theme.dart`, `app_glass.dart`
- `lib/features/chat/chat_screen.dart`
- `lib/features/home/conversations_list_screen.dart`
- `lib/features/onboarding/onboarding_screen.dart`
- `lib/widgets/glass_container.dart`
- `lib/main.dart` (splash)

## Sources & limites

Inspiré et adapté de :
- Décision produit UpChat : `plan.md`
- [aliabedi1/telegram-ui-design](https://github.com/aliabedi1/telegram-ui-design) — patterns **bots** (méthode besoins→écrans) ; **pas** un clone UI client Telegram
- [viralcode/openwhale `apple-hig`](https://github.com/viralcode/openwhale/blob/main/skills/apple-hig/SKILL.md) — principes HIG (clarté, déférence, profondeur, safe areas, a11y)

Ce skill **ne couvre pas** : Bot API Telegram, Mini Apps TON, envoi de messages bots, achats.
Pour les bots, voir `docs/skills/references/`.

## Méthode de travail

1. Partir des besoins utilisateur UpChat (offline, proximité, internet optionnel)
2. Proposer la plus petite structure d'écran qui les sert
3. S'aligner sur les tokens existants avant d'inventer des couleurs
4. Livrer des changements Flutter concrets + checklist acceptance
5. Ne jamais bloquer le démarrage sur le design réseau (Firebase optionnel)
