# AEGIS Gate — contrat V0

Statut : noyau local et CLI, sans interface Gate ni connexion du notch à ce noyau. L’étude bookmark reste préservée par le tag annoté `bookmark-study-0.4.0`, sur `75dd1bbd6a935a9116ee8815e21088cfb2b6344f`. L’expérimentation est sur `feature/aegis-gate-v0`.

## 1. Évolution explicite du contrat

La demande d’implémentation succède au contrat documentaire initial. Elle fixe trois changements : empreinte de la représentation canonique **sans le digest** plutôt que des octets bruts ; durée de vie de **30 à 900 secondes** ; stockage par défaut dans `~/Library/Application Support/Reprise/GateInbox`. Les textes sont normalisés avant signature, jamais tronqués. Le reçu a exactement les six champs demandés ci-dessous ; l’algorithme SHA-256 est fixé par la version 1, et le demandeur est couvert par le digest sans champ supplémentaire dans le reçu.

Le noyau est indépendant de `PageCapture`, `ThreadNote`, `RepriseStore`, `thread.json`, `CaptureInbox` et du pont navigateur. Il ne migre aucune référence. La compilation inclut un exécutable distinct `RepriseGate` dans le bundle construit, sans modifier le code de l’interface bookmark ni installer ou lancer le bundle. Les tests isolent tous les fichiers Gate ; ils n’utilisent pas le stockage utilisateur.

## 2. Invariants

1. Une demande décrit une action ; elle ne transporte jamais un programme à exécuter par Reprise. Aucun champ de script, hook, callback ou commande exécutable n’existe. Une chaîne ressemblant à une commande reste une donnée inerte : le noyau ne prétend pas classifier sémantiquement tout texte libre.
2. Les seules décisions sont `approve_once`, `deny`, `expired`. Reprise ne réalise jamais l’action demandée et ne peut attester son résultat.
3. Le consentement est explicite et porte uniquement sur la requête exacte validée, son UUID, son contenu canonique et son digest. Aucun consentement permanent, groupé ou implicite.
4. Toute décision est liée à cette empreinte. Une différence d’UUID, d’empreinte ou d’échéance provoque un rejet, sans nettoyage des fichiers concernés.
5. Une autorisation expire avec la requête. Aucun délai de transport, rejeu, réveil ou redémarrage ne prolonge ce droit.
6. Aucun changement silencieux de portée après signature. Modifier l’action, la cible, la portée, les preuves, le demandeur ou les dates exige une nouvelle requête et un nouveau consentement.
7. Tout texte reçu est une donnée non fiable, jamais une instruction adressée au noyau, à l’interface ou à l’agent qui l’inspecte. Les preuves sont **déclarées**, pas attestées.
8. Une décision n’est déclarée produite qu’après publication atomique et relecture vérifiée du reçu. Une notification ne prouve rien à elle seule.
9. Une demande invalide, expirée ou ambiguë n’est jamais approuvée par défaut. Silence, erreur, arrêt et timeout ne valent pas consentement.
10. Tout reste local : pas de serveur, réseau, télémétrie, compte ou modèle IA. Pas de lecture automatique des prompts, fichiers de travail, URLs, sources des preuves ou presse-papiers.

## 3. Schéma fermé et validation

`GateRequest: Codable` contient **uniquement** :

| Champ | Forme V1 |
|---|---|
| `version` | Entier `1` |
| `id` | UUID valide ; aucun chemin reçu n’est utilisé pour nommer un fichier |
| `requester` | Texte non vide, 128 octets UTF-8 maximum |
| `action` | Description non vide, 256 octets maximum |
| `target` | Cible non vide, 1 024 octets maximum |
| `scope` | Portée non vide, 2 048 octets maximum |
| `effect` | `reversible`, `difficult`, `irreversible`, `unknown` |
| `evidence` | Tableau ordonné de 0 à 8 textes non vides, 512 octets maximum chacun |
| `createdAt` | Entier de millisecondes Unix, positif ou nul |
| `expiresAt` | Entier de millisecondes Unix |
| `requestDigest` | SHA-256 canonique en 64 caractères hexadécimaux minuscules |

`GateDecision: Codable` contient **uniquement** : `version`, `requestID` (UUID), `requestDigest`, `outcome` (`approve_once`, `deny`, `expired`), `decidedAt`, `expiresAt`.

La limite d’un message est **65 536 octets (64 Kio)**, avant décodage. Le transport de fichiers utilise exclusivement `GateWire.decode`, qui contrôle taille, UTF-8, profondeur JSON, doublons de clés, y compris les alias échappés, puis les types Codable. Les champs absents ou supplémentaires, versions et valeurs d’enum inconnues sont rejetés. Les dates et la version n’acceptent pas de notation décimale ou exponentielle. Un appel direct à `JSONDecoder` n’est pas une entrée de transport autorisée.

À la création locale, suppression des espaces périphériques et normalisation Unicode NFC. Les limites s’appliquent avant **et** après normalisation ; les contrôles internes et commandes bidirectionnelles sont rejetés. Un texte reçu déjà signé doit être normalisé ; le récepteur ne le corrige pas. Aucune troncature ou substitution métier.

L’échéance doit être postérieure à la création de 30 000 à 900 000 ms incluses. La création ne peut être future à l’admission. Les dates sont bornées avant l’année 10000. Une demande déjà expirée mais structurellement valide reçoit `expired`, sans devenir autorisable. La validation structurelle ne démontre pas qu’un texte est suffisamment précis pour un consentement : cette vérification appartient aussi au futur examen humain.

## 4. Canonicalisation et liaison

La représentation canonique V1 est l’objet requête **sans `requestDigest`**, encodé en JSON UTF-8 compact :

- clés ASCII triées lexicalement ; aucun espace ajouté ;
- UUID en minuscules ; texte NFC ; ordre des preuves conservé ;
- nombres entiers en base 10 ;
- caractères Unicode non ASCII conservés, slash non échappé ; guillemet et antislash échappés conformément à JSON.

Le hash est SHA-256 de ces octets. `GateRequest.canonicalData()` est l’encodeur de référence ; le test CLI recalcule indépendamment l’empreinte avec Python. L’ordre des clés ou la casse de l’UUID dans le message reçu ne crée pas un autre droit, mais toute modification du contenu canonique change le digest. L’algorithme est fixé par `version = 1`.

L’identité d’autorisation est `(id, requestDigest)`. Le reçu doit présenter exactement cet UUID, ce digest et l’échéance d’origine. Sa date de décision ne peut précéder la création ni être future lors de sa lecture. Un reçu `expired` prématuré ou un refus daté après l’échéance est invalide. Une autorisation livrée après l’échéance est **rapportée comme `expired`**, tout en conservant le reçu original immuable pour audit.

## 5. Stockage, FIFO et reprise

Chemin par défaut : `~/Library/Application Support/Reprise/GateInbox`. `REPRISE_GATE_PATH` choisit un répertoire absolu dédié aux tests ou au diagnostic. Le répertoire Gate est `0700`, ses fichiers `0600` ; le noyau ne change pas les permissions du répertoire parent Reprise.

Un verrou `flock`, complété par un verrou dans le processus, sérialise les admissions et décisions. Les opérations de fichiers sont relatives au descripteur ouvert du répertoire, avec `O_NOFOLLOW`. Le noyau refuse les fichiers non réguliers, liens symboliques, propriétaires divergents et fichiers de protocole accessibles au groupe ou aux autres utilisateurs. Les répertoires parents appartiennent à l’environnement utilisateur de confiance ; ce mécanisme ne constitue pas un sandbox contre le même compte.

Pour chaque UUID validé, en minuscules :

- `<uuid>.entry.json` : journal immuable contenant la requête, son numéro FIFO et l’instant d’admission ;
- `<uuid>.request.json` : copie en attente destinée à la future projection ;
- `<uuid>.decision.json` : reçu terminal immuable.

La file comporte au maximum **8 requêtes non terminales**, y compris la future requête affichée. L’ordre est le numéro d’admission persistant, jamais `mtime`. Une file pleine retourne une erreur technique sans éviction ni écrasement. Les demandes expirées sont terminalisées avant de compter les places. Sans consommateur actif, les expirations des demandes `--no-wait` sont matérialisées lors du prochain accès au noyau.

Un doublon canonique retrouve la même entrée ; un UUID réutilisé avec un autre contenu est refusé. Seule la tête en attente peut recevoir un nouveau consentement ou refus via `GateStore.decide`. La future interface devra conserver l’UUID et le digest affichés et présenter toute la portée. Aucune approbation de groupe ou dépendance implicite.

Le journal est publié avant la copie en attente ; en cas d’arrêt entre les deux, la copie est reconstruite depuis le journal validé. Un reçu existant fait foi après reprise, même si la copie en attente subsiste. Une corruption provoque une erreur sans réparation silencieuse ni suppression des octets concernés.

Les journaux et reçus sont conservés pour l’anti-rejeu. La limite V0 est **1 024 admissions conservées** : une fois atteinte, refus des nouvelles admissions, sans purge automatique. La relecture et le traitement des demandes existantes restent possibles. Une politique de rétention ultérieure nécessitera un contrat distinct.

## 6. Publication des reçus et nettoyage

Toute publication utilise un fichier temporaire du même répertoire, une écriture complète, `fsync` du fichier, `renameatx_np(RENAME_EXCL)`, `fsync` du répertoire et une relecture de vérification. Le rename est atomique et refuse de remplacer une destination existante. Un échec d’écriture, de synchronisation ou de relecture interdit toute annonce de réussite ; un fichier déjà publié peut subsister pour réconciliation.

Les décisions concurrentes partagent le verrou et le premier reçu terminal reste immuable. La date est revérifiée lors de la finalisation réelle. Si un arrêt survient après publication mais avant notification, le reçu reste consultable. Les fichiers temporaires orphelins d’un arrêt brutal ne sont jamais interprétés comme demandes ou décisions.

Le nettoyage de la CLI intervient **seulement après lecture et vérification** du reçu et de la copie de demande. Il supprime uniquement `<uuid>.request.json`. Les reçus et journaux ne sont pas effacés : nettoyer toute trace détruirait l’anti-rejeu. Une copie corrompue ou un reçu divergent est conservé et fait échouer la CLI.

L’attente de la CLI est bornée par l’échéance absolue et une horloge continue incluant le sommeil du Mac. Un recul d’horloge observé fait échouer l’attente sans consentement et sans nettoyage. Le noyau refuse également un temps antérieur à l’admission persistée. Cela ne constitue pas une horloge de sécurité indépendante du système ; un changement d’horloge pendant que tous les processus sont arrêtés reste une limite de la V0.

## 7. CLI et responsabilité du demandeur

```sh
RepriseGate ask --requester "Codex" --action "Publier la branche" \
  --target "ridhafandi-dev/reprise" \
  --scope "feature/aegis-gate-v0 uniquement" \
  --effect difficult --evidence "Tests locaux réussis" --ttl 300
```

La CLI valide, signe et dépose la requête, puis émet une notification locale `tools.pulsar.reprise.gate.requestAvailable` si l’app Reprise est déjà ouverte. Elle ne lance jamais l’app et n’utilise pas la notification du pont navigateur. L’app bookmark actuelle ne traite pas ce nouveau signal ; son intégration attend la passe UI.

En mode normal, stdout contient une unique décision JSON après vérification et nettoyage, sans logs mélangés. Les erreurs vont sur stderr, sans JSON de succès. À expiration sans réponse, la CLI fait publier le reçu `expired` par le noyau, puis le relit. Elle revérifie l’expiration à la livraison, notamment après les écritures de nettoyage.

Codes de sortie pour `ask` : **0** autorisation, **2** refus, **3** expiration, **1** erreur. **4** signifie admission en attente avec `--no-wait` : option exclusivement de test/diagnostic, stdout contient alors la requête, pas une décision, et aucun fichier n’est nettoyé. `--help` affiche uniquement l’aide.

`approve_once` autorise au plus une tentative. Le demandeur doit enregistrer durablement sa consommation du couple UUID/digest avant l’action, contrôler l’expiration juste avant cette tentative et ne pas recommencer après un résultat incertain sans nouvelle demande. La CLI **n’exécute pas** cette tentative et ne garantit pas « exactement une fois » chez un demandeur arbitraire.

## 8. Frontière de confiance et limites

Cette V0 sert des processus locaux coopératifs dans une session de confiance. Un hash lie un contenu, mais n’authentifie ni le demandeur ni l’humain. Un processus malveillant du même compte, ou un administrateur, peut falsifier le stockage. Aucun IPC authentifié, contrôle de provenance du consentement ou mécanisme imposant la consommation chez le demandeur n’est livré ici. `GateStore.decide` est le point d’entrée du futur adaptateur humain ; aucune sous-commande CLI ne permet d’approuver.

La publication atomique et les `fsync` sont testés en fonctionnement, pas sous coupure électrique physique. Les pannes de stockage, horloges manipulées hors observation, authenticité du reçu et preuve réelle de consommation restent à renforcer avant une utilisation comme frontière de sécurité. Aucune interface Gate n’est construite à cette étape.

Les sept fichiers inspectés lors de l’étape initiale restent une référence technique : `Capture.swift`, `NativeHost.swift`, `Store.swift`, `CompactNotch.swift`, `App.swift`, `build.sh`, `test.sh`. Seuls les deux scripts évoluent pour compiler et tester le noyau distinct ; les captures navigateur et les fils ne deviennent pas son modèle métier.
