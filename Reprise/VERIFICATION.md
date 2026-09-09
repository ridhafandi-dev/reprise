# Reprise 0.3.0 — Vérification

## État V3 · 10 septembre 2026

Implémenté : capture navigateur par extension Chromium et pont Native Messaging local, capture directe au collage/dépôt, contexte optionnel rétrocompatible, note personnelle facultative, auteur/extrait et retour YouTube avec timestamp, copie avec source. Le volet garde ses dimensions de 288 × 280 points.

Vérifié :
- Compilation native Apple Silicon et signature ad hoc du paquet V3.
- Tests modèle et survol V2 conservés.
- Capture sans éditeur ; conservation du contexte après édition et relancement du modèle ; déduplication d’une même source/extrait ; mise à jour du timestamp ; URL de retour à 12:43 puis 13:20 ; copie de citation.
- Tests isolés de l’extracteur JavaScript : métadonnées article, sélection et text fragment, lecteur YouTube, repli sans lecteur, post X exact, repli sur un flux, rejet des pages internes.
- Tests de protocole natif : framing longueur/JSON, origine non admise, taille excessive et message invalide rejetés.
- Test de la boîte de réception isolée : accusé positif après sauvegarde, retrait du message traité, données retrouvées dans l’archive.
- Archive illisible préservée lors d’une nouvelle capture.
- Dans l’app installée V3 : trois fils antérieurs retrouvés, remise du fil Test au bord, présence des nouvelles actions Copier avec la source / Ajouter une note.

En attente : installation de l’extension et enregistrement du pont dans Dia. L’approbation automatique a refusé la création du fichier NativeMessagingHosts sans accord utilisateur plus explicite. Aucun test réel de capture X/YouTube/article depuis Dia n’est donc revendiqué à ce stade. Le comportement des sites dynamiques, le raccourci Dia et le retour exact au passage restent à vérifier dans le navigateur réel.

La distribution reste expérimentale et non notarisée. Les détails d’installation et les limites de capture figurent dans BROWSER.md.

---

## Historique : Reprise 0.2.0

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
