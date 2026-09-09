# Reprise · Identité 0.3.2

Un R ouvert dessiné comme un fil : la boucle revient, le trait repart. Le tracé est original à cette passe et partagé entre SwiftUI, la barre de menus, les icônes macOS et Chromium.

- Bleu principal : `#235CD6`, boutons avec texte blanc.
- Bleu clair : `#89A7EA`, accents sur fond sombre et trait de sortie du logo.
- Blanc : `#FFFFFF`, fond de l’app et lettre de l’icône.
- Le panneau latéral garde son noir pour s’intégrer au bord de l’écran.

Aucune modification des parcours ou de la structure intérieure de l’app. L’encoche reste à 22 × 76 points, son volet à 288 × 280. Aucun changement de stockage, capture ou permission.

## Sources et exports

`reprise-mark.svg` est la version vectorielle sur fond transparent. `Reprise-icon.png` est l’icône 1024 px, `Reprise.icns` le conteneur macOS. `../Extension/icons` contient les tailles 16, 32, 48 et 128 px.

`../BrandGeometry.swift` définit le tracé natif ; `../BrandMark.swift` l’affiche en SwiftUI et sous forme de template monochrome dans la barre de menus. `Generate.swift` génère les PNG dans l’espace sRGB. `package-icons.py` assemble les PNG dans le conteneur ICNS ; son ouverture a été vérifiée avec les outils image de macOS après un échec d’iconutil.

## Vérification de cette passe

Compilation et signature ad hoc de la version 0.3.2 réussies. Bundle remplacé et rouvert. Rendu réel inspecté dans Mes fils et le panneau latéral : nouveau signe et couleurs présents, six fils existants retrouvés.

Les fichiers de l’extension sont mis à jour en 0.3.2. Son rechargement n’a pas été confirmé par l’interface de Dia : cliquer Reload sur la carte Reprise dans chrome://extensions, puis vérifier la version 0.3.2. Les permissions et le pont local restent identiques.
