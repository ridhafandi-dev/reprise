# Reprise 0.2.0 — Vérification

## Diagnostic V1

Les captures fournies par l’utilisateur montrent un signet disproportionné et une fenêtre principalement démonstrative. Le code confirme deux causes supplémentaires : la fenêtre native était redimensionnée immédiatement alors que SwiftUI animait son contenu ; le composant de démonstration partageait le survol avec le panneau latéral.

## Changements

- Signet : 40 × 132 → 22 × 76 points, soit 68 % de surface en moins.
- Volet : 382 × 448 → 288 × 280 points, soit 53 % de surface en moins.
- Fenêtre latérale de taille fixe : seule la forme intérieure s’anime.
- Un contrôleur du pointeur, issu du schéma Codenotch : événements locaux/globaux de mouvement, contrôle de secours toutes les 150 ms, zone active limitée à la forme visible.
- Ouverture après 100 ms, grâce de fermeture de 300 ms, ressort de 300 ms amorti à 0,91. Reduce Motion respecte le réglage système.
- Mes fils remplace la démonstration. Recherche, filtre De côté, édition, rangement durable, remise au bord, copie de phrase et choix du bord.

## Vérifié

- Compilation native et signature ad hoc du paquet sur Apple Silicon/macOS 26.
- Tests du modèle : URL admises/refusées, chemins locaux, remplacement, annulation, sauvegarde, archive illisible.
- Migration d’une archive V1 sans history ni identity ; conservation de l’ancien fil et déduplication après modification.
- Tests du survol : passage de 40 ms ignoré, ouverture persistante, grâce à la sortie, retour annulant la fermeture, absence de report infini par le polling, repli explicite.
- Dans l’app : récupération du fil rangé de V1 ; ajout d’un second fil ; filtre De côté ; sélection d’un ancien fil ; remise au bord.
- Rendu inspecté : fenêtre Mes fils et volet compact, texte et actions visibles.

## Limites

Le ressenti au trackpad reste à confirmer par l’utilisateur. Les captures et les tests des délais ne prouvent pas une fluidité parfaite sur chaque écran. Le glisser-déposer n’a pas été éprouvé avec chaque application source. Pas de validation Intel, VoiceOver, multi-écran ou plein écran exhaustif ; le signet reste sur le premier écran. La fenêtre intérieure ne contient plus une seconde encoche qui commanderait la première.

Les fichiers sont référencés par leur chemin. Aucun contenu de fichier n’est copié. Les fils conservés restent locaux, sans cloud ni compte IA. Distribution expérimentale non notarisée.
