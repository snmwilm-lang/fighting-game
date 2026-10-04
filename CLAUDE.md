# Instructions pour Claude

- Lire `docs/Roblox_Guide_Claude.md` (cahier des charges) et `docs/JOURNAL.md` (état actuel)
  avant toute modification. Le propriétaire est Wilhem ; répondre en français.
- Le code est synchronisé par Rojo : `src/shared` → ReplicatedStorage.Shared,
  `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client.
  Ne jamais committer de `.rbxlx`.
- `src/shared/CombatSimulation.luau`, `FighterAI.luau`, `CinematicDirector.luau`,
  `Animator.luau`, `Kinematics.luau`, `PoseLibrary.luau`, `RigSpec.luau`, `Retarget.luau`,
  `PressQueue.luau`, `SoundPalette.luau`, `WeaponSpec.luau`, `OrbFlight.luau`, `FourArms.luau`, `Locale.luau` et `Maps.luau` restent purs (aucune API Roblox, aucun `require` : les dépendances sont passées en
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
- Cinématiques : composer les plans avec `frameOn` (angle, plongée, part de l'écran), jamais
  un décalage de caméra à la main ; vérifier le rendu avec le storyboard
  (`luau tests/Storyboard.luau -a KIT Rush|Awaken|Gate`, puis `python3 tools/storyboard.py`).
- `src/server/Lobby.luau` (règles du hub), `src/server/Matchmaker.luau` (recherche, Elo) et
  `src/shared/GameModes.luau` (modes du menu) restent purs aussi (tests : `Lobby.test.luau`). Après une retouche de
  `RigBuilder.luau` (corps, tenues), lancer `python3 tools/rigcheck.py check` (et
  `python3 tools/rigcheck.py render rigs.png` pour voir les persos).
- La géométrie du rig KAI vit dans `RigSpec.luau` (utilisée par le RigBuilder et les tests) :
  ne pas la dupliquer. Celle des armes (katana de SHIN, orbe de DAICHA) vit dans
  `WeaponSpec.luau` : un coup d'arme doit vraiment balayer la lame / mener avec l'orbe (tests
  « weapons » d'Animation, planche `PoseSheet` qui dessine l'arme).
- Le client ne décide jamais d'un coup, de la vie ni du KO ; les effets sont cosmétiques.
- Ne jamais affirmer avoir testé dans Roblox Studio. Pas d'ID d'asset (son, animation,
  texture) inventé. Les sons ne viennent que de `SoundPalette.CLIENT_SOUNDS` (les fichiers
  réellement livrés avec le client) ; chaque perso garde sa matière sonore.
- Après chaque livraison, mettre à jour `docs/JOURNAL.md` (version, fichiers, tests,
  problèmes ouverts, prochaine étape).
- Le jeu est écrit en anglais (langue source de la traduction automatique de Roblox). Tout
  nouveau texte affiché doit avoir sa traduction française dans `src/shared/Locale.luau`
  (`Locale.FR`, ou `Locale.SAME` si le mot est identique) : le test « languages » de
  `Lobby.test.luau` le vérifie.
- Les arènes : données dans `src/shared/Maps.luau`, construites côté client par
  `src/client/ArenaBuilder.luau`. Le sol de combat (y = 0, x de -28 à 28) ne change jamais.
