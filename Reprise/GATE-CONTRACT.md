# AEGIS Gate — contrat V0

Statut : contrat de la nouvelle expérimentation, sans implémentation. Ce document ne décrit pas une fonctionnalité disponible dans l’étude bookmark.

## 1. Préservation et périmètre

L’étude Reprise 0.4.0 est préservée intégralement au commit `75dd1bbd6a935a9116ee8815e21088cfb2b6344f`, sous le tag annoté `bookmark-study-0.4.0`. L’expérimentation part de ce commit sur `feature/aegis-gate-v0`.

Cette étape ajoute uniquement ce contrat. Aucun changement du code produit, aucune interface, aucun exécutable, aucune installation, aucune migration et aucune publication distante. L’app installée et `~/Library/Application Support/Reprise` restent hors du périmètre d’écriture.

La future Gate aura un espace de stockage et une identité de processus distincts, à définir avant son implémentation. Elle ne réutilisera ni `thread.json`, ni `CaptureInbox`, ni l’identité du pont navigateur. `PageCapture`, `ThreadNote`, le presse-papiers et les fils ne sont pas son modèle métier.

## 2. Responsabilités et invariants

Un demandeur local soumet la description bornée d’une action. Un humain peut l’autoriser une fois ou la refuser. Reprise produit uniquement une décision ; le demandeur reçoit un reçu lié exactement à sa requête.

1. Une demande décrit une action, mais ne contient jamais de code à exécuter. Aucun script, commande shell, programme, expression évaluable, hook ou callback exécutable n’est admis par le protocole.
2. Les seules décisions métier sont `approve_once`, `deny` et `expired`.
3. Reprise n’exécute jamais l’action demandée : aucun lancement de commande, ouverture de cible, envoi, écriture métier ou appel au demandeur pour agir à sa place. L’écriture de sa propre file et de ses reçus appartient au protocole, pas à l’action demandée.
4. L’autorisation vaut uniquement pour la requête exacte reçue, avec son demandeur, son action, sa portée et son échéance. Toute décision est liée à son empreinte.
5. Une autorisation expire avec la requête. Il n’existe ni autorisation permanente, ni permission implicite, ni prolongation automatique.
6. Aucun changement silencieux de portée : pas de correction, substitution de cible, ajout, réduction, regroupement ou normalisation métier après réception. Toute modification exige une nouvelle requête et un nouveau geste humain.
7. Tout texte reçu est une donnée non fiable, jamais une instruction adressée à Reprise. Un titre, une justification ou un nom de demandeur ne peut modifier ce contrat ni commander l’interface.
8. Une décision n’est déclarée produite qu’après écriture atomique de son reçu et vérification de cette écriture.
9. Une requête invalide, expirée ou ambiguë n’est jamais autorisée par défaut. Silence, fermeture du notch, délai de transport, erreur disque et redémarrage ne valent pas consentement.
10. Tout reste local : aucun serveur réseau, télémétrie, compte, modèle IA ou récupération distante de contexte. Reprise ne suit aucun lien reçu.

## 3. Requête immuable et empreinte

Le futur schéma versionné devra contenir au minimum : version, identifiant unique de requête, identité déclarée du demandeur, description d’une seule action, portée explicite et bornée, date de création et date d’expiration. La portée doit identifier les ressources concernées et l’effet demandé. Une description qui laisse la cible ou l’effet indéterminé reste non autorisable.

Bornes retenues pour cette V0 : un message UTF-8 JSON d’au plus 64 Kio, une seule action par requête et une durée maximale de 15 minutes entre création et expiration. Les horodatages seront des entiers de millisecondes Unix ; la création ne peut pas être future à l’admission et l’expiration doit être strictement postérieure à la création. Ces bornes ne sont jamais corrigées à la volée : dépassement ou incohérence entraîne un rejet technique.

Le schéma sera fermé : champs inconnus, clés JSON dupliquées, encodage invalide, valeurs de type inattendu et champs obligatoires absents sont rejetés. Il n’offre aucun champ destiné au transport de code. Le nom exact des champs et les catégories d’actions admises doivent être figés avant d’accepter une requête ; aucune catégorie inconnue ne bénéficie d’un fallback permissif.

L’empreinte V0 est `SHA-256` des **octets UTF-8 exacts du corps reçu**, avant toute transformation, hors éventuel en-tête de longueur du transport. Les octets originaux sont conservés immuables avec cette empreinte. Aucun trim, changement d’ordre des clés, arrondi, troncature, re-sérialisation ou normalisation Unicode n’intervient dans le calcul. Deux sérialisations différentes sont donc deux empreintes différentes, même si leurs objets JSON semblent équivalents.

La validation et la présentation doivent dériver du même corps conservé. L’identité d’une demande admise est le couple `(request_id, request_fingerprint)` ; `request_id` est globalement unique dans l’espace Gate. Le reçu inclut également l’identité déclarée du demandeur et l’expiration d’origine, toutes deux déjà couvertes par l’empreinte. Une empreinte assure la liaison au contenu, pas l’authenticité du demandeur.

Un texte ambigu ne doit pas être complété par une inférence. Il est rejeté à l’admission si le schéma ne suffit pas ; si l’ambiguïté est constatée pendant l’examen humain, la requête peut être refusée ou laissée expirer, jamais approuvée sans clarification par une nouvelle requête.

## 4. Admission et petite file FIFO

La V0 accepte jusqu’à **8 requêtes admises non terminales**, y compris celle présentée dans le notch. Chaque demande est indépendante ; aucune approbation groupée, dépendance implicite ou remplacement du fil actif n’existe.

- Un seul propriétaire local sérialise l’admission et l’attribution d’un numéro de séquence persistant, strictement croissant. Le FIFO suit cet ordre d’admission, pas l’horloge du demandeur, le nom de fichier ou la date de modification du système de fichiers.
- L’admission est confirmée seulement après conservation durable de la requête et de sa position. Elle n’est jamais présentée comme une décision ou une autorisation.
- Une file pleine entraîne une réponse technique de saturation. Aucun élément n’est évincé, écrasé ou acquitté fictivement. Le demandeur peut réessayer avec les mêmes octets et le même identifiant.
- Un doublon exact en attente retrouve la même entrée, sans nouvelle place ni nouveau rang. Un doublon exact déjà décidé retrouve le même reçu, sans nouveau droit d’action.
- Un identifiant déjà connu avec une autre empreinte est un conflit : rejet technique, conservation de l’original, aucune substitution.
- Une demande déjà expirée et autrement valide reçoit `expired` après persistance atomique du reçu, sans prendre la place d’une demande en attente. Une demande dont les champs ne sont pas validables reçoit un rejet technique, sans reçu d’autorisation.
- Le notch ne projette qu’une requête à la fois : la plus ancienne encore en attente et non expirée. Les requêtes en attente expirent aussi pendant qu’une autre est affichée ; elles sont terminalisées en `expired` sans être proposées à l’approbation.
- Une demande suivante ne devient actionnable qu’après finalisation de la précédente. Un incident de stockage bloque la transition concernée ; il ne justifie jamais sa suppression silencieuse.

Les réponses de transport/admission (`rejet invalide`, `conflit`, `saturation`, `en attente`, `erreur de stockage`) ne sont pas des décisions métier. Aucune d’elles ne vaut `approve_once`.

## 5. Geste humain et expiration

La future projection doit permettre de vérifier le demandeur déclaré, l’action, toute sa portée et son échéance. Un texte tronqué ou une partie inaccessible ne peut être la seule base d’une approbation. Cette obligation décrit l’information nécessaire, pas une interface à construire à cette étape.

Le geste explicite d’autorisation ou de refus est lié au couple identifiant/empreinte affiché et à son état en attente. Il ne s’applique jamais simplement à « la tête actuelle de la file ». Si la requête affichée a changé, expiré ou déjà reçu une décision, le geste périmé est sans effet autorisant. Un double clic ne produit pas deux décisions.

L’expiration est contrôlée à l’admission, à l’affichage et lors de la finalisation. À `now >= expires_at`, la décision applicable à une demande encore en attente est `expired`. Un refus explicite d’une requête encore valide produit `deny`. Une autorisation exige une requête toujours valide et un consentement explicite sur ses octets immuables.

Le temps de vie ne se remet pas à zéro à la réception, au rejeu, au réveil du Mac ou au redémarrage. Une horloge monotone borne l’attente dans une session ; l’expiration absolue conservée borne la reprise. Un recul d’horloge ou une incertitude temporelle empêchant d’établir la validité ne doit jamais prolonger un droit ni permettre une approbation.

Même un reçu `approve_once` écrit ou livré tardivement n’est plus utilisable à partir de l’expiration d’origine. Le demandeur doit contrôler cette échéance au moment de consommer l’autorisation, indépendamment de l’affichage de Reprise.

## 6. Reçu atomique et remise de la décision

Un reçu terminal contient au minimum : version du protocole, identifiant de requête, empreinte SHA-256 et algorithme, identité déclarée du demandeur, décision parmi les trois valeurs, instant de décision et expiration d’origine. Pour `approve_once`, la limite de validité est exactement celle de la requête, sans délai supplémentaire.

Le reçu est immuable. Une seule finalisation peut gagner pour un couple identifiant/empreinte : consentement, refus, expiration et reprise après incident doivent partager la même exclusion mutuelle. Une nouvelle décision ne remplace jamais un reçu terminal existant.

Ordre obligatoire :

1. Vérifier sous contrôle de concurrence l’identité, l’empreinte, l’état en attente et l’échéance ; préparer la décision pour cette requête précise.
2. Écrire le reçu complet dans un fichier temporaire du même volume, puis le publier atomiquement sans écraser un reçu existant. Les opérations exactes de synchronisation et de reprise doivent être définies et éprouvées avant implémentation livrable ; `.atomic` seul ne démontre pas la tenue à une coupure électrique.
3. Vérifier le reçu publié et sa liaison à la requête. Une erreur ou un état incertain interdit toute annonce de décision produite. Un fichier partiel ou contradictoire ne vaut jamais autorisation.
4. Après cette finalisation seulement, annoncer la décision disponible, marquer l’entrée terminale et avancer la projection. Le reçu persistant fait foi si le processus s’arrête entre ces étapes ; la reprise doit réconcilier la file avec les reçus.

Un réveil ou une notification n’est qu’un signal de disponibilité, pas une décision. Le demandeur obtient le reçu local correspondant exactement à son identifiant et à son empreinte. Il rejette tout reçu divergent, incomplet, expiré ou inconnu. Un timeout ne prouve ni absence ni production d’une décision : le demandeur relit ou réinterroge la même requête, sans en déduire une permission.

La lecture ne supprime pas le reçu. Les reçus et les identités terminales nécessaires à l’anti-rejeu sont conservés dans la V0 ; aucune purge automatique. Une limite de stockage atteinte bloque les nouvelles admissions plutôt que d’effacer cette protection. Une politique de purge future nécessitera un contrat explicite.

## 7. Sens de « une fois » et frontière de confiance

`approve_once` autorise au plus une tentative de l’action décrite par la requête exacte. La lecture répétée du même reçu ne crée pas plusieurs autorisations. Le demandeur doit enregistrer atomiquement et durablement la consommation du couple identifiant/empreinte avant sa tentative, vérifier l’échéance et ne pas rejouer l’action si son résultat devient incertain. Une nouvelle tentative exige une nouvelle demande et un nouveau consentement.

Reprise n’exécute pas cette tentative, n’atteste pas sa réussite et ne peut pas garantir à elle seule qu’un demandeur obéit au reçu. Le protocole ne promet donc ni exécution exactement une fois, ni effet métier démontré. Un reçu atteste une décision, pas une action accomplie.

La V0 vise des demandeurs locaux coopératifs dans une session utilisateur de confiance. Une identité textuelle, un argument d’origine ou un hash ne constitue pas une authentification. Un processus malveillant du même compte pouvant écrire les fichiers Gate peut falsifier requêtes ou reçus ; un administrateur est également hors de cette garantie. Les permissions locales, l’absence de liens symboliques et la validation des fichiers limitent des erreurs et certaines interférences, sans transformer ce prototype en barrière contre un agent local hostile.

Avant toute extension de ce périmètre, il faudra définir l’authentification du demandeur, la provenance du reçu et un mécanisme de consommation réellement imposé. Aucune promesse de sécurité inter-processus n’est implicite dans cette V0.

## 8. Inspection de l’étude bookmark : réutilisation à borner

| Source inspectée | Observation actuelle | Conséquence pour Gate |
|---|---|---|
| `Capture.swift` | `PageCapture.validated()` tronque les textes, substitue une catégorie et arrondit la position vidéo ; reçu limité à `ok/error`. | Ne pas réutiliser ce validateur ni cet accusé comme modèle d’autorisation ; aucune transformation silencieuse et reçu lié à l’empreinte. |
| `NativeHost.swift` | Corps borné à 64 Kio ; fichiers par UUID ; suppression d’un ancien `.ack`, écriture pouvant remplacer la même entrée, délai de 8 s et suppression du reçu après lecture. | La longueur bornée et la boîte locale inspirent le transport ; conflits, idempotence, conservation des reçus et attente humaine demandent un autre protocole. |
| `Store.swift` | `receive()` déduplique par URL/extrait, remplace le fil actif ; `drainCaptures()` trie par date de modification ; `openSource()` ouvre des URL/fichiers. | Aucun de ces effets métier n’appartient à Gate. FIFO persistant, entrées indépendantes, aucun appel d’exécution ou d’ouverture de cible. |
| `CompactNotch.swift` | Projection du fil actif, textes abrégés, actions de copie/édition/ouverture et drop de références. | Seules géométrie et mécanique de projection peuvent inspirer la suite ; une décision exige une portée lisible et un geste lié à l’identité exacte. |
| `App.swift` | Drain automatique de `CaptureInbox`, notifications et polling ; identité bookmark ; panneau non activant. | Isolation obligatoire des chemins/processus ; une notification ne vaut pas consentement. Aucun démarrage de cette app pour tester Gate à cette étape. |
| `build.sh` | Compile et signe l’app bookmark et son pont, puis copie les bundles. | Script inspecté seulement, non exécuté ; aucun binaire Gate et aucun remplacement de l’app installée. |
| `test.sh` | Compile des exécutables de tests du modèle, hover et capture ; lance aussi les tests JS d’extension. | Script inspecté seulement, non exécuté ; ces tests ne prouvent aucun invariant Gate. |

## 9. Épreuves requises avant une future livraison

Ces épreuves sont des exigences futures, pas des tests créés ou passés dans cette étape :

- identifiant réutilisé avec une portée modifiée, Unicode/JSON ambigu, champ inconnu ou charge trop grande : jamais d’autorisation ;
- mêmes octets renvoyés avant/après décision : une entrée, un reçu, aucun droit supplémentaire ;
- neuf demandes concurrentes : huit admissions au plus, aucune perte, ordre d’admission persistant ;
- double clic, expiration pendant le geste, changement de tête entre affichage et clic : aucune décision appliquée à une autre requête ;
- arrêt avant/après publication du reçu, disque plein, accusé perdu : aucune réussite annoncée avant persistance, réconciliation sans seconde autorisation ;
- sommeil du Mac, recul d’horloge, redémarrage après échéance : aucun droit prolongé ;
- chemins falsifiés, liens symboliques, reçus contradictoires : rejet sûr dans le périmètre local défini ;
- inventaire des effets : uniquement stockage/notification du protocole, aucun code ou action métier exécuté par Reprise ;
- coexistence avec l’étude : aucun accès d’écriture à son stockage et aucune altération de son bundle installé.

Fin de l’étape contractuelle. L’implémentation, le transport détaillé, les tests exécutables et l’interface attendent une instruction ultérieure.
