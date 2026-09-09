# Reprise 0.3.3 — Carte à tranche

## Livré
- Lecture sur feuille claire, tranche de commandes au bord, filigrane R, pied de reprise bleu.
- Dimensions conservées : fermé 22×76, ouvert 288×280, canvas 288×304 points.
- Padding16 pour la lecture ; espaces4/8/12/16 ; échelle12/16/24 points. La tranche mesure56, cibles32. Le rythme de la bibliothèque est hors scope.
- Tranche inversée au bord gauche. Labels accessibles et aides sur les icônes. Retour visuel local au hover et au clic, animation supprimée avec Reduce Motion.
- Aucune mutation du schéma de données, aucune modification de l’extension (reste0.3.2).

## Vérifications de cette passe
- Build natif optimisé + signature ad hoc stricte réussis. Une métadonnée FinderInfo ajoutée à la copie Documents a été retirée ; vérification stricte du bundle livré ensuite réussie.
- Suite Reprise complète : modèle/persistence/migration, hover, capture et extracteur JS passent.
- App réelle : carte ouverte à droite puis à gauche ; bord droit rétabli. Copie affiche la confirmation et la coche. Annotation ouvre le bon fil, annulée sans enregistrer. Retour Mes fils fonctionnel. Sept fils conservés.
- Hash du fichier utilisateur identique avant/après les essais : aucune note modifiée.
- Neuf rendus SwiftUI hors écran : courant, gauche, post X, titre/note longs, sans URL, erreur, vide, drop, fermé. La découpe extérieure donne des bandes jaunes dans ImageRenderer, absentes du panneau natif : ces rendus ne sont pas la preuve du contour. Le contenu, sa lisibilité et l’absence de chevauchement ont été inspectés ; le contour est vérifié dans l’app réelle.
- Pas de mesure instrumentée de FPS, de test VoiceOver complet ni de nouveau glisser-déposer réel dans cette passe. Le réglage Reduce Motion est respecté par code ; aucun changement des préférences système pour le tester.

## Retour
Tag git `reprise-before-card-0.3.2` et ZIP du bundle précédent fourni dans Reprise-retour. Fermer Reprise avant tout remplacement. Les données restent hors du bundle.

---

# Reprise 0.3.2 — Identité

Nouveau R vectoriel, icône macOS ICNS et icônes Chromium 16/32/48/128. Palette #235CD6 / #89A7EA / blanc. Compilation et signature ad hoc réussies, app mise à jour et rendus Mes fils / encoche inspectés. Structure intérieure et comportements conservés. Six fils existants retrouvés.

Extension : fichiers 0.3.2 préparés ; rechargement dans Dia non confirmé par l’outil UI (version affichée encore 0.3.1). Un clic Reload reste nécessaire. Détails dans Brand/README.md.

---

# Reprise 0.3.1 — Vérification

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

Validation réelle dans Dia, après accord explicite :
- Extension 0.3.1 chargée et pont NativeMessagingHosts installé ; vérification du chemin de l’exécutable et de l’origine autorisée.
- Activation depuis le menu Extensions > Reprise : post X « Experimenting with Blur & Gradients » enregistré avec auteur et URL exacte, intention vide ; accusé consommé et boîte de réception vide.
- Présence du post et de son auteur dans l’interface Mes fils, sans formulaire de capture.
- Copie avec source vérifiée en la collant dans un brouillon de l’app, ensuite annulé sans sauvegarde.
- Conflit réel avec ⌘⇧S (affichage des onglets Dia). Remplacement par l’action native de l’extension `_execute_action` sur ⌃⇧R ; rechargement confirmé en 0.3.1 puis capture par ce raccourci vérifiée dans le fichier de l’app.
- Reprise arrêtée : le menu de l’extension lance automatiquement l’app, sauvegarde une nouvelle capture du post et consomme l’accusé ; app observée en cours d’exécution ensuite.
- Rendu final inspecté au bord : type POST X, titre, auteur, Revoir le post, copie, note facultative et Ranger visibles.
- Deux captures du même post/extrait conservent le même fil. Correction de l’espace entre le nom et le @ de l’auteur.

Limites restantes : YouTube et les text fragments d’article disposent de tests isolés ; leur parcours réel dans Dia n’a pas été validé dans cette session. Aucun parcours réel non testé n’est présenté comme démontré.

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
