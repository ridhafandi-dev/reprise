# Reprise · Capture au bord

Reprise 0.3.0 ajoute une extension Chromium et un pont natif local. Aucun serveur, aucun compte. L’extension lit le contexte de la page uniquement au clic sur son icône ou au raccourci. La note est facultative.

## Installer depuis les sources

1. Exécuter `bash Reprise/build.sh /chemin/de/sortie`.
2. Exécuter `python3 Reprise/install-browser.py --app /chemin/de/sortie/Reprise.app --extension /chemin/du/repo/Reprise/Extension --browser dia`.
3. Dans `chrome://extensions`, charger le dossier `Reprise/Extension` avec « Load unpacked » (mode développeur).
4. Depuis une page web, cliquer sur Reprise dans les extensions ou utiliser **⌃⇧R**. Si le raccourci est déjà pris, le régler dans `chrome://extensions/shortcuts`.

Le pont est enregistré dans le dossier NativeMessagingHosts de Chrome, utilisé ici par le moteur d’extensions de Dia. Il cible le chemin exact de l’app : relancer l’installation après déplacement de celle-ci. L’identifiant stable de l’extension est `dkfcpfbnnjoginaefpfhpidocihpbine`.

Dans Dia, le clic sur Reprise, le raccourci **Contrôle + Maj + R** et le lancement de l’app fermée ont été vérifiés avec un post X. ⌘⇧S est réservé à la disposition des onglets de Dia et n’est plus utilisé.

## Geste

- Garder : le contenu apparaît directement au bord, sans voler le clavier ni ouvrir l’éditeur.
- Consulter : survoler le signet ; titre, auteur et extrait disponibles s’affichent.
- Utiliser : ouvrir la source, reprendre la vidéo à l’instant capturé, ou copier le texte avec sa source.
- Ajouter un mot : le bouton crayon ouvre la note facultative.
- Ranger : libérer le bord ; le fil reste dans Mes fils. Annuler permet de le remettre.

## Ce qui est capturé

- Page : URL, titre, auteur et description lorsqu’ils sont présents ; sélection de texte si elle existe. La sélection ajoute un lien vers le passage, dont la résolution dépend du navigateur et de la stabilité de la page.
- YouTube : titre, chaîne, position du lecteur lorsqu’il est chargé. Sans lecteur disponible, lien simple. La vidéo est rouverte sur YouTube avec `t=` ; aucun téléchargement ou transcription.
- X : pour un lien direct `/utilisateur/status/id`, le post exact et son auteur sont extraits s’ils sont rendus. Sinon, repli sur les métadonnées disponibles. Aucun chargement du thread complet ni des réponses.
- Presse-papiers et dépôt : capture directe de texte, lien ou fichier, sans détection du contexte du navigateur.

Une nouvelle capture du même lien et du même extrait actualise la référence existante et conserve la note personnelle. Une sélection différente peut créer une autre référence.

## Données et limites

Les fils restent dans `~/Library/Application Support/Reprise/thread.json`. Les messages en attente passent par le sous-dossier `CaptureInbox` (accès limité au compte macOS). Le pont confirme uniquement après enregistrement. Un message non confirmé peut rester en attente pour le prochain lancement. Les anciens fils sont conservés. Un fichier d’archive illisible n’est pas remplacé par une nouvelle capture.

Permissions extension : `activeTab`, `scripting`, `nativeMessaging`, `storage`. Pas d’historique, pas de lecture continue, pas de capture d’écran, pas de requêtes réseau ajoutées. Les pages internes du navigateur sont exclues. Le contenu de la page est traité comme du texte, jamais comme une commande.

Cette version n’intègre pas Reader, Raindrop ou Notion. Elle ne restaure pas tout un espace de travail et n’infère pas ton intention.

## Désinstaller le pont

Retirer l’extension Reprise dans la page des extensions et supprimer uniquement `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/tools.pulsar.reprise.json`. Les fils restent dans Reprise.
