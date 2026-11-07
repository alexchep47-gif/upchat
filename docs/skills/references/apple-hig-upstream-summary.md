# Upstream — apple-hig (synthèse)

Source principale consultée :  
https://github.com/viralcode/openwhale/blob/main/skills/apple-hig/SKILL.md  

Référence officielle Apple :  
https://developer.apple.com/design/human-interface-guidelines/

> Aucun fichier nommé `appleskills.md` n'existe sur GitHub. Les skills publics s'appellent en général `apple-hig` ou `ios-hig-design`.

## Principes retenus pour UpChat (Flutter)

### Clarity
- Texte lisible à chaque taille
- Icônes précises
- Fonctionnalité évidente via le contenu

### Deference
- Le contenu occupe l'écran ; UI discrète
- Translucidité / blur pour suggérer plus de contenu
- Peu de bordures / ombres lourdes

### Depth
- Couches visuelles + motion pour la hiérarchie
- Transitions fluides pour l'orientation spatiale

## iOS / iPadOS (applicable Flutter)

- Interaction tactile ; portrait / paysage
- **Safe areas** : notch, Dynamic Island, home indicator
- Gestes : tap, long press, swipe
- Navigation : tab bar 3–5 destinations ; barre de nav hiérarchique
- Listes groupées inset (moderne)
- Sheets avec detents

## Typo & couleur

- Sur iOS natif : SF Pro + Dynamic Type — en Flutter : respecter le text scaler système / réglage app
- Couleurs sémantiques light/dark
- Contraste WCAG AA minimum (4.5:1 texte normal)
- Accent = actions interactives uniquement

## Layout

- Grille **8 pt**
- Marges ~16 (téléphone)
- Cibles tactiles confortables (≥ 44 pt)

## Accessibilité

- Labels accessibilité
- Support grandes tailles de texte
- Alternative si « reduce motion »
- Tester clair + sombre

## Motion

- Rapide 0.2–0.3 s | Standard 0.3–0.5 s
- Ease in/out ou spring léger
- Continuity des éléments entre écrans

## Dark mode

- Tester les deux modes
- Éviter le noir pur sauf OLED volontaire
- Surfaces « élevées » par légère variation de gris/bleu, pas seulement plus clair

## Non repris tels quels dans UpChat

- SF Symbols exclusifs Apple (Flutter Material / Cupertino icons)
- Live Activities / Dynamic Island natifs
- App Clips, widgets Lock Screen
- visionOS / tvOS / watchOS
