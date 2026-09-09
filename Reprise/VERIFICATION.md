# Vérification de Reprise 0.1.0

Base upstream : `0a6c6fb62b7fda52e4f8bd1ce7e8c7e7b8595b75`.

## Exécuté

- Compilation native Swift/SwiftUI/AppKit sur macOS 26, Apple Silicon.
- Tests du modèle : URL non prises en charge refusées, chemins locaux acceptés, remplacement, libération et annulation, sauvegarde/relecture, refus d’écraser silencieusement une archive illisible.
- Ouverture de l’app et inspection visuelle de la présentation, du volet déplié et de l’éditeur.
- Saisie et sauvegarde d’un fil d’essai ; vérification du texte rendu dans le volet.
- Libération de la place puis annulation ; retour du fil vérifié dans l’interface.
- Clic sur Reprendre : ouverture de la bonne URL GitHub confirmée dans le navigateur.

## Limites de cette première livraison

- Glisser-déposer implémenté avec les types natifs URL/fichier/texte, mais la diversité des apps sources n’est pas encore validée.
- Pas de validation sur Intel, sur macOS 15, avec VoiceOver, plusieurs écrans ou toutes les apps en plein écran.
- Pas de notarisation ni de mise à jour automatique.
- Le bénéfice sur la reprise d’attention est une hypothèse à éprouver en usage réel.
