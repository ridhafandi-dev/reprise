# Reprise — Étude 01

Un petit endroit au bord de l’écran pour garder où l’on en était.

**Une app macOS native expérimentale, dérivée de [Codenotch](https://github.com/vinzdg/codenotch).** Un signet ambré se déplie en un fil : une intention, une source, un bouton pour revenir. Le premier lancement propose un exemple explicitement étiqueté.

## Le geste

1. Survoler le signet sur le bord droit, ou utiliser le menu Reprise.
2. Déposer un lien, un fichier ou un extrait ; ajouter où reprendre.
3. Garder ce fil. Le volet se referme.
4. Revenir au signet et ouvrir la source. Le fil reste en place jusqu’à ce qu’on le libère.

Une seule place, avec un précédent récupérable par **Annuler**. Pas de liste de tâches, d’échéances ou de compte à connecter.

## Construire

Les Command Line Tools d’Apple suffisent (Swift 6.2.1 testé sur macOS 26). Aucun package externe n’est téléchargé pour cette cible.

```sh
bash Reprise/build.sh
open build/reprise/Reprise.app
```

Le script compile pour l’architecture du Mac utilisé. La version livrée localement est Apple Silicon, signée ad hoc, non notarisée. Ce n’est pas une distribution publique prête à installer sur tous les Mac.

## Tester le modèle

```sh
swiftc Reprise/Thread.swift Reprise/Tests.swift -o /tmp/reprise-tests
/tmp/reprise-tests
```

Les tests portent sur les sources autorisées, le remplacement réversible, la libération, la persistance et les archives illisibles. Voir [la vérification](Reprise/VERIFICATION.md) pour ce qui a réellement été essayé dans l’interface.

## Ce qui vient de Codenotch

`SideNotchShape.swift` et `NotchMotion.swift` sont compilés directement depuis les sources d’origine. Le panneau non activant est adapté de `NotchPanel.swift`. La géométrie conserve les courbes inversées qui attachent la forme au bord de l’écran ; les dimensions et le contenu changent.

La cible Reprise ne compile aucun provider IA, aucun accès aux identifiants et aucun updater. Les sources Codenotch sont préservées pour poursuivre le fork, avec leur [README d’origine](README.Codenotch.md). Les workflows hérités sont limités au dépôt upstream pour ne pas publier une app Codenotch sous le nom Reprise.

## Données et limites

- Le fil et son précédent sont conservés dans `~/Library/Application Support/Reprise/thread.json`. `REPRISE_STATE_PATH` permet d’isoler les essais.
- Les fichiers déposés sont référencés par leur chemin, pas copiés. S’ils sont déplacés, il faut modifier le fil.
- Les liens HTTP(S) et les fichiers locaux peuvent être ouverts après un clic explicite. Aucun aperçu distant n’est téléchargé.
- Aucun presse-papiers n’est lu automatiquement : seulement via l’action Coller.
- Bord droit ou gauche du premier écran. Pas encore de choix de moniteur, de synchronisation ni de raccourci global.
- Les modifications en cours ne sont pas enregistrées avant « Garder ce fil ». Une seule étape d’annulation est conservée.

## Licence

MIT. Copyright Codenotch © 2026 Vinz conservé dans [LICENSE](LICENSE), y compris dans le bundle Reprise. Modifications Reprise, 2026.
