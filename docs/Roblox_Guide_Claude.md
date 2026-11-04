# Jeu Roblox de combat 2.5D — Guide pour Claude

Version 1.0 — 30 septembre 2026 — Propriétaire du projet : Wilhem.

Ce fichier est le cahier des charges à joindre à Claude. Il décrit un projet à construire progressivement, pas un jeu déjà implémenté. Les valeurs proposées sont des points de départ à tester.

## 1. Ta mission

Tu es responsable de l'implémentation Luau et des instructions d'installation dans Roblox Studio. ChatGPT prépare et révise le design, l'architecture et les corrections. Wilhem installe, joue, crée ou importe les assets et décide du résultat souhaité.

Lis ce fichier entièrement. Au premier échange, résume les choix structurants, puis livre uniquement la phase 1. Lors des échanges suivants, examine les fichiers réellement présents et le dernier rapport de test avant toute modification. N'affirme jamais avoir testé dans Studio si tu n'y as pas accès.

Objectif : un versus original avec personnages 3D, gameplay sur un plan 2D, caméra latérale, compatible clavier/souris, manette et tactile. Street Fighter et Dragon Ball FighterZ sont des références de sensations et de mise en scène ; Tekken est une référence de combat et d'impact, pas de déplacement en profondeur pour ce projet.

## 2. Direction visuelle demandée

Wilhem souhaite une esthétique anime en cel shading, proche des principes visuels de FighterZ : silhouettes fortes, couleurs en aplats, ombres tranchées, contours, poses exagérées et mouvements par paliers. Créer des personnages, décors, interfaces et effets originaux.

Bien distinguer trois cadences :

| Couche | Objectif initial | Règle |
|---|---|---|
| Affichage du jeu | Viser 60 FPS sur les appareils ciblés | Dépend du matériel ; ne pas imposer une limite artificielle à 12 FPS |
| Combat | Tick logique visé à 60 Hz | Frame data indépendante du nombre d'images rendues |
| Pose visuelle | Tester 12, 15 et 24 changements par seconde | Certains impacts peuvent avoir une cadence plus élevée |

Ces cadences sont nos propositions, pas une affirmation sur la cadence réelle de FighterZ. Une animation à 12 poses/seconde dans un jeu affiché à 60 FPS conserve environ chaque pose pendant cinq images. À 15 poses/seconde, environ quatre ; à 24, la durée moyenne n'est pas un nombre entier d'images. Calculer selon le temps, sans supposer que chaque appareil affiche 60 FPS.

Caméra, UI, déplacement de la racine et collecte des inputs restent fluides. Seules certaines poses et certains effets utilisent des paliers. Une pose maintenue ne doit pas retarder une hitbox ni une entrée.

### Approche graphique adaptée à Roblox

Commencer avec des matériaux simples, textures peintes en aplats, ombres peintes contrôlées, un éclairage cohérent et éventuellement un Highlight pour tester les contours. Le Highlight ne remplace pas des traits intérieurs dessinés. SurfaceAppearance fournit des textures PBR ; ce n'est pas, à lui seul, un shader toon.

Ne pas promettre un shader GLSL/HLSL personnalisé installé comme dans Unity. Vérifier les capacités actuelles de Roblox avant de proposer une technique. Des textures avec ombres peintes sont une approximation artistique : elles ne changent pas automatiquement avec chaque éclairage. Un contour par coque de mesh exige une vérification de l'import, des normales, du rig et du coût ; ne pas le choisir avant un essai concluant.

Faire un essai isolé avec un mannequin, une lumière, une pose d'attente et un coup de poing avant de produire tous les assets. Tester face droite ET face gauche : des textures et ombres peintes peuvent mal fonctionner après retournement.

### Approche d'animation

Privilégier des poses clés maintenues avec transitions adaptées plutôt qu'une animation fluide simplement ralentie. Vérifier l'easing Constant sur les poses et les interpolations introduites par les mélanges de tracks. Désactiver les animations par défaut uniquement pour les combattants et gérer explicitement les priorités et transitions.

Si une méthode d'échantillonnage de poses est nécessaire, proposer un prototype séparé. Modifier TimePosition périodiquement n'est pas une solution garantie : vérifier blending, marqueurs, réplication et retour en boucle. Ne pas multiplier les contrôleurs qui écrivent simultanément les articulations.

Les markers servent surtout aux SFX/VFX et à l'édition. Les fenêtres de dégâts, invulnérabilité et cancels viennent de la simulation autoritaire. Un marker client ne décide jamais qu'un adversaire est touché.

## 3. Décisions à fixer avant le code

Conventions proposées : X = gauche/droite, Y = hauteur, Z = profondeur verrouillée. Plan de combat Z = 0. Les valeurs de vitesse et limites d'arène sont centralisées. Les mouvements horizontaux représentent gauche/droite à l'écran ; avant/arrière est calculé depuis l'orientation vers l'adversaire.

Lors d'une attaque, l'orientation est verrouillée jusqu'à une transition autorisée. À distance horizontale presque nulle, conserver la dernière orientation pour éviter un tremblement. Prévoir des pushboxes distinctes des hurtboxes : les combattants ne se traversent pas au sol ; le changement de côté par saut pourra être ajouté selon les règles validées.

Le prototype solo utilise le combattant du joueur et un dummy. Le test à deux clients utilise un combattant par joueur. Décrire précisément le lien Player/Character/Fighter et le remplacement du dummy ; deux modèles posés dans Workspace ne deviennent pas automatiquement des joueurs contrôlables.

### Inputs et réseau : vérification obligatoire

Roblox documente désormais un Input Action System (InputContext, InputAction, InputBinding) et un modèle Server Authority avec simulation prédite. Vérifier leur disponibilité dans le Studio utilisé avant de choisir l'implémentation. Préférer ces outils s'ils sont disponibles et appropriés ; ne pas utiliser des événements d'input traditionnels au cœur d'une simulation Server Authority qui attend des InputActions.

Si ce chemin n'est pas utilisable, livrer un prototype classique avec adaptateurs d'input, validations serveur et limites de latence annoncées. ContextActionService peut servir d'adaptateur classique ; les commandes tactiles personnalisées passent par la même interface logique. Ne pas mélanger silencieusement deux architectures réseau.

Écrire la décision dans le journal du projet. Une solution classique avec validation des dégâts n'est pas équivalente à un rollback complet. Tester le réseau dès la phase 1 et le premier coup en phase 2, plutôt que convertir tout un jeu solo à la fin.

## 4. Architecture cible

Créer seulement les éléments utiles à la phase courante. Conserver ces noms sauf décision documentée :

| Emplacement | Élément | Type / responsabilité |
|---|---|---|
| Workspace | Arena | Model : sol et limites |
| Workspace | Fighters | Folder : combattants présents |
| ServerStorage | FighterTemplates | Folder : modèles de test |
| ReplicatedStorage/FightingGame/Shared | CombatConfig | ModuleScript : valeurs globales |
| ReplicatedStorage/FightingGame/Shared | InputConfig | ModuleScript : actions et bindings |
| ReplicatedStorage/FightingGame/Shared | CharacterData | ModuleScript : données de personnage |
| ReplicatedStorage/FightingGame/Shared | MoveData | ModuleScript : attaques |
| ReplicatedStorage/FightingGame/Shared | StateMachine | ModuleScript : états et transitions |
| ReplicatedStorage/FightingGame/Shared | CombatSimulation | ModuleScript : logique de combat réutilisable |
| ReplicatedStorage/FightingGame | Inputs | Folder : templates de contexts si Input Action System |
| ReplicatedStorage/FightingGame | Remotes | Folder : messages nécessaires au chemin réseau choisi |
| ReplicatedStorage/FightingGame/Assets | Animations, VFX, SFX | Folders : références d'assets |
| ServerScriptService/FightingGame | ServerBootstrap | Script : initialisation |
| ServerScriptService/FightingGame/Services | FighterService, CombatService, HitboxService, MatchManager | ModuleScripts : autorité et cycle du match |
| StarterPlayer/StarterPlayerScripts | ClientBootstrap | LocalScript : initialisation |
| StarterPlayer/StarterPlayerScripts/FightingGame | InputController, FighterController, CameraController, AnimationController | ModuleScripts : côté client |
| StarterGui | CombatHUD, MobileControls | ScreenGui : affichage et commandes |

Un ModuleScript doit être explicitement chargé par un bootstrap ; il ne s'exécute pas seul. Expliciter l'ordre d'initialisation et les dépendances. Pas de dépendances circulaires. Aucun identifiant d'animation inventé ; les placeholders restent clairement indiqués et ne bloquent pas le test de mouvement.

## 5. Contrat des inputs

Actions : MoveAxis, Jump, Crouch, Dash, LightAttack, MediumAttack, HeavyAttack, Special, Block, Grab. MoveAxis est une valeur entre -1 et 1 ; les autres distinguent début, maintien et relâchement selon leur besoin.

| Action | Clavier proposé | Manette proposée | Mobile proposé |
|---|---|---|---|
| Horizontal | A/D ou Q/D | Stick gauche ou croix | Joystick gauche |
| Saut | Espace | Haut de la croix | Bouton saut |
| Accroupi | S maintenu | Bas de la croix | Bas joystick |
| Léger / moyen / lourd | J / K / L | X / Y / B sur Xbox | L / M / H |
| Spécial | U | A sur Xbox | SP |
| Garde | I maintenu | RB maintenu | Garde maintenue |
| Dash | Shift + direction | RT + direction | Dash + direction |
| Prise | O | LB | Prise |

Bindings à confirmer en jeu ; afficher les symboles appropriés selon le périphérique. La souris sert aux menus pour le prototype. Si une attaque au clic est souhaitée, l'ajouter dans l'adaptateur.

Gérer deadzone du stick, pressions simultanées gauche/droite (neutre proposé), changement de périphérique, saisie dans le chat, perte de focus et boutons relâchés lors d'un reset. Ne pas envoyer un RemoteEvent à chaque image rendue. L'input buffer est réglable et sera ajouté avec les attaques. Les inputs, même transmis par le moteur, restent soumis aux règles du combat.

## 6. Procédure de travail pour chaque livraison

1. Donner l'objectif et les critères de réussite de la phase.
2. Donner la liste exacte des éléments à créer : chemin, nom, classe, propriétés importantes.
3. Donner le code complet de chaque nouveau script. Pour une modification courte, proposer soit un patch précisément localisé, soit le fichier complet si c'est plus simple pour Wilhem.
4. Donner l'ordre d'installation, puis les actions manuelles séparées du code.
5. Ne pas demander d'activer l'accès HTTP ou les API de production sans besoin concret.
6. Donner un test solo et un test serveur avec deux clients quand pertinent, puis les tests manette/tactile.
7. Indiquer ce qui a réellement été vérifié et ce qui reste à tester dans Studio.
8. Donner les erreurs probables et la façon de collecter les logs, sans masquer les erreurs derrière des pcall généralisés.
9. Terminer par un résumé des fichiers modifiés et un état de projet que Wilhem peut joindre à ChatGPT.
10. Attendre le rapport de test avant la prochaine grosse phase ; corriger la phase actuelle si nécessaire.

État minimal à transmettre : version, phase, architecture réseau choisie, fichiers créés/modifiés, conventions, assets requis, tests passés/échoués/non exécutés, problèmes ouverts, prochaine étape. Les décisions et fichiers actuels priment sur une ancienne proposition.

## 7. Préparation manuelle dans Roblox Studio

Indiquer les noms d'outils selon la version actuelle ; si leur emplacement varie, donner leur nom et fonction plutôt qu'un faux chemin de menu.

Wilhem doit :

1. Ouvrir Studio sur ordinateur et créer une place Baseplate. Nom provisoire : FightingPrototype.
2. Afficher Explorer, Properties et Output. Sauvegarder une copie locale du projet avant chaque phase validée.
3. Préparer le sol, les limites et deux points de spawn ; tu fournis dimensions et propriétés exactes lors de la phase 1.
4. Créer deux rigs R15 avec l'outil de génération de rigs. Utiliser un modèle joueur de test et un dummy distinct, selon ton mécanisme de spawn explicite.
5. Créer les dossiers/scripts indiqués, coller les codes hors mode Play et vérifier les noms.
6. Lancer Play, vérifier le résultat, Stop, puis modifier. Les changements d'instances en session de test ne doivent pas être confondus avec la place sauvegardée.
7. Tester Server & Clients avec deux clients ; chacun doit contrôler seulement son propre combattant.
8. Utiliser l'émulation d'appareil pour le layout tactile, puis un vrai téléphone pour gestes, confort et performance. Un émulateur de résolution ne représente pas la puissance du téléphone.
9. Tester une vraie manette, puis ultérieurement une vraie console avant d'annoncer sa compatibilité.
10. Fournir erreurs complètes, capture de l'Explorer, périphérique et courte vidéo si le comportement est visuel.

Tu peux proposer un script de construction d'arène limité à un dossier nommé FightingGame. Expliquer ce qu'il crée avant exécution. Ne jamais supprimer tous les enfants de Workspace ou remplacer tout le projet pour installer une phase.

## 8. Phases et validation

### Phase 1 — Fondation jouable

Livrer arène, joueur + dummy en solo, association de deux joueurs en test multiclient, déplacement X, saut Y, Z verrouillé, limites, retournement, caméra et inputs des trois familles. Inclure seulement les états nécessaires au mouvement. Caméra centrée sur les deux combattants, distance adaptée à leur séparation et au ratio de l'écran. Pas d'attaque complexe.

Valider : absence de dérive Z ; saut stable ; limites respectées ; caméra lisible aux deux extrémités et en écran mobile ; neutralisation du déplacement lors du chat ; relâchement du stick/bouton sans mouvement bloqué ; respawn sans double connexion ; deux clients associés correctement. Si le dummy empêche un croisement, prévoir un mode de test explicite pour l'orientation sans casser les futures pushboxes.

### Phase 2 — Un coup complet

Ajouter LightAttack, startup/active/recovery, hurtbox et hitbox logiques, vie, hitstun, knockback et affichage debug. Un coup ne touche qu'une fois la même cible, sauf attaque multi-hit déclarée. Aucun client ne choisit dégâts ou résultat. Tester dès maintenant à deux clients et avec latence simulée si disponible.

### Phase 3 — Défense et rounds

Garde haute/basse, catégories high/mid/low documentées, blockstun, knockdown, get-up, KO, timer et deux rounds gagnants. Définir double KO et timeout avant implémentation. Reset de toutes les données : vie, jauge, états, buffer, projectiles et effets persistants. Tester qu'un joueur KO ne peut plus attaquer et qu'un round ne se termine qu'une fois.

### Phase 4 — Combos

Ajouter moyen/lourd/spécial, cancels autorisés, confirmation hit/block explicite, compteur et réduction de dégâts bornée. Empêcher les boucles infinies involontaires. Tester corner, échanges simultanés, buffer, interruption d'attaque et fin de combo après récupération réelle du défenseur.

### Phase 5 — Essai visuel anime

Faire un essai idle + marche + un punch. Comparer 12/15/24 poses par seconde et version fluide, sur PC et téléphone. Le combat doit rester identique entre modes. Ajouter impact frame bref, hitstop réglable et contours ; un hitstop est un événement de combat contrôlé, pas un freeze arbitraire de tout le moteur. Ne pas faire avancer silencieusement les fenêtres actives pendant un gel censé les suspendre.

### Phase 6 — Premier personnage original

Importer ou créer le modèle, rig, textures et animations validés. Ajouter attaques aériennes, prise et super selon le moveset approuvé. Chaque asset doit fonctionner dans la place publiée avec les droits appropriés. Le second combattant peut rester une copie mécanique pour tester.

### Phase 7 — Robustesse du versus

Consolider prédiction/réconciliation du chemin retenu, messages, déconnexions, reconnexion aux matchs selon les règles choisies, performance et résultats autoritaires. Ne pas annoncer un rollback fonctionnel sans preuve de tests et prise en charge de resimulation. Séparer effets de présentation et simulation pour éviter les sons répétés après correction réseau.

### Phases 8 à 10 — Expansion

Sélection de personnage, entraînement, puis matchmaking. L'entraînement inclut dummy réglable et affichage de frame data. Pas de ranked/MMR, économie ou boutique avant un versus stable. Le mobile/manette est testé tout au long du projet, puis reçoit une passe finale de confort et performance.

## 9. Données et sécurité à conserver

MoveData décrit au minimum : ID, startup/active/recovery en ticks, dégâts, hitstun, blockstun, knockback, type de garde, hitboxes locales orientées, règles de cancel, coût/gain de jauge et références de présentation. Définir exactement les bornes des intervalles pour éviter les erreurs d'une frame.

Séparer hurtbox, hitbox et pushbox. Ne pas utiliser uniquement Touched sur un poing animé comme système de combat. Si un projectile rapide peut traverser une cible entre deux ticks, prévoir une détection balayée.

Validation : types, valeurs finies, taille des messages, appartenance au match, combattant vivant, état, coûts, cadence et séquences obsolètes. Limitation de débit côté serveur pour les remotes. Le client ne fixe ni vie, ni jauge, ni KO, ni récompenses. Tester aussi les positions et la propriété réseau dans un chemin classique : valider seulement les dégâts ne protège pas les déplacements.

Une frame logique à 60 Hz dure environ 16,67 ms. Les timings ne dépendent pas de RenderStepped ni de task.wait(1/60). Documenter le mécanisme de tick choisi, le rattrapage sous charge et les limites observées. Si Server Authority est utilisé, suivre ses exigences de simulation et de stockage d'état, pas une table Lua mutable supposée automatiquement restaurée.

## 10. Limites de l'aide IA

Le code généré peut contenir des erreurs et doit être exécuté. L'IA peut fournir tables de poses, outils et scripts d'aide, mais un rig animé et un rendu anime final exigent des ajustements artistiques. Wilhem teste le ressenti, crée/import les assets, vérifie leurs droits et valide les appareils. Sans accès effectif à Studio, l'IA ne peut ni publier les animations ni garantir la performance ou la compatibilité console.

## 11. Message à envoyer avec ce fichier

« Lis ce cahier des charges et respecte-le. Le projet est nouveau, aucun script n'est encore confirmé. Commence uniquement par la phase 1. Vérifie le choix entre Input Action System/Server Authority et prototype classique. Donne tous les chemins, types d'instances, propriétés, scripts complets, actions manuelles et tests. Garde l'objectif anime/cel shading/poses par paliers pour la suite, sans ralentir les inputs ni la caméra. Termine par un état de projet à transmettre à ChatGPT. »

## 12. « Make it cool » — consignes de mise en scène

Le combat doit avoir de la personnalité : anticipation lisible, pose de contact forte, récupération expressive. Chercher l'impact avec une combinaison réglable de hitstop, son bref, étincelle dessinée, petite secousse de caméra et réaction du défenseur. Garder les effets courts pour lire l'action suivante.

Pour les coups forts : smear visuel, lignes de vitesse, poussière directionnelle, impact frame de contraste et déformation visuelle contrôlée du rig si compatible. Les effets sont cosmétiques et ne changent pas les hitboxes. Prévoir une option de réduction des secousses et flashs.

Pour une super : courte anticipation, cadrage rapproché ou cut-in original, puis retour garanti à la caméra de combat, y compris après interruption, KO ou déconnexion. Les angles cinématiques restent réservés aux moments explicitement autorisés ; préserver la caméra latérale pendant le jeu normal.

UI : barres de vie lisibles, compteur de combo expressif, annonce de round avec caractère, palette cohérente et boutons tactiles confortables. Proposer deux ou trois directions originales avant le premier personnage. Aucun effet coûteux généré en masse chaque image. Prévoir qualité VFX réduite sur mobile en conservant les informations importantes.

Le premier test de style doit déjà rendre un simple punch satisfaisant. Ne pas attendre dix personnages pour travailler le son, les poses et le rythme. Les intensités sont des paramètres à ajuster par Wilhem en jeu.

## Sources techniques à vérifier avant implémentation

Documentation consultée le 30 septembre 2026. Les choix artistiques et cadences ci-dessus sont nos propositions.

- [Input Action System](https://create.roblox.com/docs/input/input-action-system)
- [Server authority model](https://create.roblox.com/docs/projects/server-authority)
- [Sécurité client-serveur](https://create.roblox.com/docs/scripting/security/client-server-boundary)
- [Tests Studio](https://create.roblox.com/docs/studio/testing-modes)
- [AnimationTrack](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)
- [PoseEasingStyle](https://create.roblox.com/docs/reference/engine/enums/PoseEasingStyle)
- [Textures PBR / SurfaceAppearance](https://create.roblox.com/docs/art/modeling/surface-appearance)
