# ram-watcher

Petit widget de bureau Windows (PowerShell + WinForms, aucune dépendance à installer) qui affiche en direct la RAM/CPU de la machine et qui consomme quoi, avec de quoi réagir en urgence.

Contexte : sur une machine qui fait tourner Chrome + Docker/WSL2 + plusieurs agents en parallèle sur 32 Go de RAM, la RAM finit par saturer et tout plante. `ram-watcher` donne une vue en direct pour repérer le coupable et agir avant que ça plante.

Voir aussi [`perfguard-mcp`](../perfguard-mcp) : la version "pour un LLM" du même monitoring, en serveur MCP, pour qu'un agent vérifie la charge avant de lancer des tâches en parallèle plutôt que de deviner.

## Ce que ça affiche

- RAM utilisée / totale + barre, RAM libre
- CPU global + barre
- Répartition par groupe surveillé : Chrome, Claude/Node, Docker/WSL
- Top 5 process par RAM
- Le fond du widget passe orange à 75 % de RAM utilisée, rouge à 90 %

## Boutons d'urgence

- **Tuer le plus gros process** — tue le process qui consomme le plus de RAM à l'instant T, peu importe son nom
- **Tuer Chrome** / **Tuer Claude/Node** / **Tuer Docker/WSL** — tue tous les process du groupe
- Champ texte + bouton **Tuer** — tue un process par son nom
- Chaque bouton demande confirmation avant d'agir

## Logs

Le widget écrit une ligne toutes les ~10 secondes dans `ramwatcher.log.csv` (même dossier) : horodatage, RAM, CPU, répartition par groupe, top 5 process. Rotation automatique quand le fichier dépasse 5 Mo (`ramwatcher.log.old.csv`). Bouton **Ouvrir les logs** pour les révéler dans l'explorateur.

## Installation

Aucune dépendance : PowerShell et .NET WinForms sont déjà présents sous Windows.

1. `git clone <url-du-repo>`
2. Double-clique `RamWatcher.vbs` (lance le `.ps1` sans afficher de fenêtre de console)

Pour qu'il démarre automatiquement à l'ouverture de session, place un raccourci vers `RamWatcher.vbs` dans le dossier de démarrage (`Win+R` → `shell:startup`).

## Utilisation

- Clique-glisse la zone de stats en haut pour déplacer le widget
- Clic droit → Quitter pour le fermer

## Licence

MIT
