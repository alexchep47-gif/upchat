# Matrice de validation UI UpChat

Cette matrice suit la refonte décrite dans `Prompt_Correction_UpChat(1).pdf`.

| Écran / composant | Clair | Sombre | OLED | Vérifications |
|---|---:|---:|---:|---|
| Splash / démarrage | ☐ | ☐ | ☐ | Logo agrandi, halo bleu, fondu/échelle, barre de progression vitrée |
| Onboarding | ☐ | ☐ | ☐ | Carte vitrée, texte lisible, boutons bleus, aucune barre verte |
| Connexion | ☐ | ☐ | ☐ | Formulaire lisible, erreur utilisateur non technique |
| Échanges | ☐ | ☐ | ☐ | Filtres vitrés, bannière réseau vitrée, liste lisible |
| Navigation basse | ☐ | ☐ | ☐ | Capsule vitrée, sélection bleue, fond clair en mode clair |
| Stories | ☐ | ☐ | ☐ | Anneau en dégradé bleu uniquement |
| Conversation | ☐ | ☐ | ☐ | Fond dégradé, actions et saisie vitrées, bulles animées |
| Réglages | ☐ | ☐ | ☐ | Interrupteurs bleus, cartes thémées, dialogues cohérents |

## Jetons verts remplacés

Les anciens jetons `#128C7E`, `#25D366`, `Colors.green` et `Colors.teal` ne sont plus utilisés pour l’activation ou les stories. Les états actifs utilisent `AppColors.primary` (bleu UpChat). Le jeton de présence est conservé comme alias bleu pour éviter une régression de compatibilité.
