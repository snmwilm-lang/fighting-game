# Instructions pour Claude

- Lire `docs/Roblox_Guide_Claude.md` (cahier des charges) et `docs/JOURNAL.md` (état actuel)
  avant toute modification. Le propriétaire est Wilhem ; répondre en français.
- Le code est synchronisé par Rojo : `src/shared` → ReplicatedStorage.Shared,
  `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client.
  Ne jamais committer de `.rbxlx`.
- `src/shared/CombatSimulation.luau`, `FighterAI.luau`, `CinematicDirector.luau`, `Finishers.luau`,
  `Animator.luau`, `Kinematics.luau`, `PoseLibrary.luau`, `RigSpec.luau`, `Retarget.luau`,
  `PressQueue.luau`, `SoundPalette.luau`, `WeaponSpec.luau`, `OrbFlight.luau`, `KiBall.luau`, `FourArms.luau`, `Locale.luau`, `Maps.luau`, `Music.luau`, `Taunts.luau`, `KitFX.luau`, `Prediction.luau`, `Economy.luau`, `Quests.luau`, `StoreConfig.luau`, `Store.luau`, `Tutorial.luau`, `UIArt.luau`, `Wire.luau`, `VfxConfig.luau` et `WeaponFX.luau` restent purs (aucune API Roblox, aucun `require` : les dépendances sont passées en
  paramètre) pour rester testables. Lancer `luau tests/CombatSimulation.test.luau`,
  `luau tests/FighterAI.test.luau`, `luau tests/CinematicDirector.test.luau`,
  `luau tests/Animation.test.luau`, `luau tests/Kits.test.luau`,
  `luau tests/PressQueue.test.luau`, `luau tests/Fuzz.test.luau`,
  `luau tests/Cinematography.test.luau` et `luau tests/Lobby.test.luau` après chaque changement, et
  ajouter un test pour chaque règle de combat, plan de caméra ou animation nouvelle (poses :
  pieds au sol, limites des articulations, pas de glissade ; R15 et R6). Juger le R6 avec la
  planche `luau tests/PoseSheet.luau -a KIT` (puis `python3 tools/storyboard.py`).
- Les 8 kits (KAI, TARO, ZEPHYR, AKEMI, RYUKEN, SHIN, DAICHA, HIBECARES) partagent la grammaire des combos : un kit associe
  chaque rôle de KAI à ses propres coups (`MoveData.luau`). Après toute retouche de dégâts,
  de vie ou de vitesse, relancer `luau tests/Balance.luau -a 4 120` (CPU contre CPU) et
  noter les chiffres dans le journal : aucun kit sous 35 % ni au-dessus de 65 % en moyenne.
- Mouvement : juger les animations en mouvement avec `luau tests/AnimClip.luau -a KIT SCRIPT 60 2 1.8`
  (puis `python3 tools/storyboard.py clip.txt clip.gif`) et `luau tests/AnimQuality.luau -a all`
  (à-coups, tremblements, interpénétration) avant et après une retouche d'animation.
  L'orbe de DAICHA : `luau tests/OrbQuality.luau -a all` (fluidité mesurée comme en jeu) et
  `luau tests/OrbClearance.luau -a all` (jamais dans son corps ni collée à elle à l'écran) avant et après.
  Les armes tenues (SHIN, RAIJIN, YUKINA, KAZAN) : `luau tests/WeaponClearance.luau -a all` (jamais dans le
  corps de leur perso) ; les gros sauts d'articulation de tous les persos : `luau tests/AnimPops.luau -a 50 list`.
  Gros plan d'une arme seule : `luau tests/WeaponCloseup.luau -a KIT` (pièces `rot` comprises).
  Les tenues de lance de RAIJIN (deux mains, `KIT_HOLD` de PoseLibrary) se calculent avec `luau tests/RaijinHold.luau -a all`,
  la garde de SHIN avec `luau tests/ShinGuard.luau -a all`, celle de YUKINA avec `luau tests/YukinaGuard.luau -a all`,
  celle de KAZAN avec `luau tests/KazanGuard.luau -a all`. Un duel CPU complet (bosses compris) : `luau tests/BossDuel.luau -a KIT1 KIT2 [n] [niveau]`.
- Cinématiques : composer les plans avec `frameOn` (angle, plongée, part de l'écran), jamais
  un décalage de caméra à la main ; vérifier le rendu avec le storyboard
  (`luau tests/Storyboard.luau -a KIT Rush|Awaken|Gate`, puis `python3 tools/storyboard.py`) ;
  un FATAL FINISHER (`Finishers.luau`) : `luau tests/Storyboard.luau -a KIT Fatal - 1 20`.
- `src/server/Lobby.luau` (règles du hub), `src/server/Matchmaker.luau` (recherche, Elo) et
  `src/shared/GameModes.luau` (modes du menu) `src/server/SaveQueue.luau` (quand écrire les profils) `src/server/GlobalQueue.luau` (CLASSÉ entre serveurs, verrou de session) et `src/server/AntiCheat.luau` (suspicion, anti-farm), `src/server/DevAccess.luau` (accès développeur), `src/server/Admin.luau` (commandes du propriétaire dans le chat), `src/server/Champions.luau` (champion de la semaine) et `src/server/Profile.luau` (valeurs par défaut du profil et fusion du chargement : tout champ qu'un module écrit dans le profil y figure, test « saved profile » de `Lobby.test.luau`) restent purs aussi. La boutique (Game Pass, Developer Products, cosmétiques) : tous les IDs et prix dans `src/shared/StoreConfig.luau` (0 = pas encore créé, jamais d'ID inventé), les règles dans `src/shared/Store.luau`, le guide dans `docs/MONETISATION.md` ; aucun Game Pass ne donne d'avantage en combat (tests : `Lobby.test.luau`). Après une retouche de
  `RigBuilder.luau` (corps, tenues), lancer `python3 tools/rigcheck.py check` (et
  `python3 tools/rigcheck.py render rigs.png` pour voir les persos).
- La géométrie du rig KAI vit dans `RigSpec.luau` (utilisée par le RigBuilder et les tests) :
  ne pas la dupliquer. Celle des armes (katana de SHIN, orbe de DAICHA) vit dans
  `WeaponSpec.luau` : un coup d'arme doit vraiment balayer la lame / mener avec l'orbe (tests
  « weapons » d'Animation, planche `PoseSheet` qui dessine l'arme).
- Le client ne décide jamais d'un coup, de la vie ni du KO ; les effets sont cosmétiques.
- Ne jamais affirmer avoir testé dans Roblox Studio. Pas d'ID d'asset (son, animation,
  texture) inventé. Les sons ne viennent que de `SoundPalette.CLIENT_SOUNDS` (les fichiers
  réellement livrés avec le client) ou de `SoundPalette.UPLOADS` (les envois de Wilhem, IDs
  donnés par lui, par usage : coups, whoosh, garde, K.O., dash, barrage, ultimes, acier) ;
  chaque perso garde sa matière sonore.
- Après chaque livraison, mettre à jour `docs/JOURNAL.md` (version, fichiers, tests,
  problèmes ouverts, prochaine étape), et à chaque livraison sans exception construire la place
  (`python3 tools/build_place.py . <scratchpad>/BREAKFRAMEZ_vX.Y.Z.rbxlx`) et l'envoyer à Wilhem.
- Le jeu est écrit en anglais (langue source de la traduction automatique de Roblox). Tout
  nouveau texte affiché doit avoir sa traduction française dans `src/shared/Locale.luau`
  (`Locale.FR`, ou `Locale.SAME` si le mot est identique) : le test « languages » de
  `Lobby.test.luau` le vérifie.
- Le pack VFX de Wilhem : fichiers dans `assets/vfx` (textures PNG, meshes FBX), IDs dans
  `src/shared/VfxConfig.luau` (0 = pas encore envoyé, jamais d'ID inventé ; `python3 tools/vfxids.py liste.txt`
  écrit les IDs qu'il donne), modules du pack dans `src/client/VFX`, pont avec le jeu dans
  `src/client/VfxPack.luau` (un effet du pack ne s'affiche que si tous ses assets ont un ID, sinon l'effet
  du jeu reste). Après une retouche : `python3 tools/vfxcheck.py`, `python3 tools/vfxsmoke.py` et
  `python3 tools/vfxrun.py` (le pack joué effet par effet sur une copie stricte du moteur, vérifiée contre l'API
  Roblox réelle de `tools/RobloxApi.luau` ; `--refresh` la réécrit depuis le dump d'API de Roblox).
- Les agents (`.claude/agents`) :
  - `idees` range les idées de Wilhem dans `docs/IDEES.md` ;
  - `production` produit, décide et note ses décisions dans `docs/DECISIONS.md` ;
  - `validation` vérifie tout avant une livraison et rend VALIDÉ ou REFUSÉ, sans rien modifier ;
  - `bugs` tient `docs/BUGS.md`, sans rien corriger.
  Le circuit : idée → production → validation → livraison ; un bug → production → validation.
  `luau` manque ? `bash tools/get_luau.sh "$HOME/.local/bin"`. La place : `python3 tools/build_place.py . dossier/BREAKFRAMEZ_vX.Y.Z.rbxlx`.
  Une routine les lance seuls chaque matin vers 6 h, heure de Paris, dans la session du jeu (qui a le dépôt en écriture :
  push automatique) : chasse aux bugs, tri des idées, une seule livraison validée, puis un rapport. Elle ne fait jamais
  ce qui attend Wilhem.
- Les arènes : données dans `src/shared/Maps.luau`, construites côté client par
  `src/client/ArenaBuilder.luau`. Le sol de combat (y = 0, x de -28 à 28) ne change jamais.
