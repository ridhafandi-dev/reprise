# Vérification de Reprise 0.1.0

Base upstream : `0a6c6fb62b7fda52e4f8bd1ce7e8c7e7b8595b75`.

## Exécuté

- Compilation native Swift/SwiftUI/AppKit sur macOS 26, Apple Silicon.
- Tests du modèle : URL non prises en charge refusées, chemins locaux acceptés, remplacement, libération et annulation, sauvegarde/relecture, refus d’écraser silencieusement une archive illisible.
- Ouverture de l’app et inspection visuelle de la présentation, du volet déplié et de l’éditeur.
- Saisie et sauvegarde d’un fil d’essai ; vérification du texte rendu dans le volet.
- Libération de la place puis annulation ; retour du fil vérifié dans l’interface.
- Clic sur Reprendre : ouverture de la bonne URL GitHub confirmée dans le navigateur.
- Conservation du fil après fermeture et relancement de l’application.
- Présentation finale : titre et sous-titre complets, volet réel intégré, ouverture par clic physique sur le signet, édition et sauvegarde vérifiées.
- Signature ad hoc vérifiée dans le répertoire de packaging ; archive sans les métadonnées Finder ajoutées par File Provider dans Documents.

## Limites de cette première livraison

- Glisser-déposer implémenté avec les types natifs URL/fichier/texte, mais la diversité des apps sources n’est pas encore validée.
- Les actions du panneau non activant sont partiellement accessibles à l’outil de pilotage. Le clic physique sur le même composant a été vérifié dans la fenêtre de présentation ; le geste latéral reste à éprouver directement au pointeur par l’utilisateur.
- Pas de validation sur Intel, sur macOS 15, avec VoiceOver, plusieurs écrans ou toutes les apps en plein écran.
- Pas de notarisation ni de mise à jour automatique.
- Le bénéfice sur la reprise d’attention est une hypothèse à éprouver en usage réel.
