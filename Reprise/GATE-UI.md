# AEGIS Gate V0 — projection humaine

Le build de cette branche utilise `tools.pulsar.reprise.gate`. L’app installée bookmark conserve son identité `tools.pulsar.reprise.study`. `App.swift` n’instancie pas `RepriseStore`, ne charge pas `thread.json`, n’écoute pas `CaptureInbox` et n’ouvre aucune bibliothèque ou éditeur bookmark.

## Parcours

- Au repos : onglet latéral fermé 22 × 76 pt, marque Reprise statique, aucun compteur ou contenu bookmark.
- Première requête FIFO valide : ouverture de 2 secondes sans activation de l’application. Ensuite ouverture au survol après 100 ms, fermeture après 300 ms hors de la carte. Aucun défilement dans la file.
- Carte 416 × 560 pt : demandeur, échéance, action, cible, portée complète défilable, effet, au plus deux preuves déclarées non vérifiées. Le nombre d’autres demandes est informatif.
- Réversible : un clic. Autres effets : premier clic armant « Confirmer cette portée » pour 5 secondes, second clic nécessaire. UUID, digest et requête affichée sont revérifiés. Expiration, modification, erreur de stockage, recul d’horloge ou fermeture annulent la confirmation.
- Fermeture et arrêt de l’app ne décident rien. La CLI ou la prochaine lecture du noyau peut matérialiser une expiration normale.
- Après publication atomique : reçu 416 × 336 pt avec résultat, heure et portée pendant 5 secondes ; puis requête suivante, ou fermeture. Un reçu peut être refermé volontairement ; son délai de transition continue.
- Menu : démonstration synthétique marquée `DÉMONSTRATION`, refus de toutes les demandes présentes au moment du geste, quitter. Le refus global conserve un reçu par requête et les présente successivement ; les demandes arrivées ensuite ne sont pas incluses.

## Réutilisation visuelle

`SideNotchShape`, `RepriseGlass`, `SurfaceFold`, `RepriseMark`, `Ink` et `SurfaceButton` sont réutilisés. Aucune nouvelle palette. Axe gauche commun ; marges de contenu 16 pt, rail latéral réservé de 32 pt, marges verticales 24 pt ; espacements 8/12/16 pt ; trois tailles de texte 18/16/12 pt. Aucun texte de portée tronqué. La transition de taille respecte Réduire les animations ; aucune animation continue du compteur.

## Vérification

`GateSessionTests.swift` utilise le véritable `GateStore` dans des répertoires temporaires, avec horloges contrôlées : 16 scénarios couvrent repos, FIFO, ouverture brève, effets, confirmation et annulation, fermeture sans décision, corruption, expiration, reçu/digest, délai avant progression, refus global et démonstration.

La suite `Reprise/test.sh` couvre aussi les 36 scénarios du noyau, 12 scénarios CLI et les suites bookmark/hover/capture/extension existantes. Le build compile et signe l’app et la CLI. Les tests visuels utilisent l’accessibilité macOS sur le build temporaire, des demandes synthétiques, et des captures de sa seule fenêtre ; les actions décrites ne sont pas exécutées.

## Limites

Le panneau est fixé au bord droit du premier écran, sans personnalisation ni parcours clavier complet validé. Les lectures du stockage sont synchrones sur le thread principal (file bornée à 8 ; journal jusqu’à 1 024 admissions) ; des entrées nombreuses ou un disque lent peuvent retarder le rafraîchissement. L’authentification inter-processus, la résistance aux horloges manipulées et l’exécution unique côté demandeur restent les limites du contrat noyau. Aucun de ces tests ne transforme une déclaration de preuve en preuve vérifiée.
