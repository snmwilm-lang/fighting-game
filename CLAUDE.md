# Instructions pour Claude

- Lire `docs/Roblox_Guide_Claude.md` (cahier des charges) et `docs/JOURNAL.md` (état actuel)
  avant toute modification. Le propriétaire est Wilhem ; répondre en français.
- Le code est synchronisé par Rojo : `src/shared` → ReplicatedStorage.Shared,
  `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client.
  Ne jamais committer de `.rbxlx`.
- `src/shared/CombatSimulation.luau`, `FighterAI.luau`, `CinematicDirector.luau`,
  `Animator.luau`, `Kinematics.luau`, `PoseLibrary.luau`, `RigSpec.luau`, `Retarget.luau` et
  `PressQueue.luau` restent purs (aucune API Roblox, aucun `require` : les dépendances sont passées en
  paramètre) pour rester testables. Lancer `luau tests/CombatSimulation.test.luau`,
  `luau tests/FighterAI.test.luau`, `luau tests/CinematicDirector.test.luau`,
  `luau tests/Animation.test.luau`, `luau tests/Kits.test.luau` et
  `luau tests/PressQueue.test.luau` après chaque changement, et
  ajouter un test pour chaque règle de combat, plan de caméra ou animation nouvelle (poses :
  pieds au sol, limites des articulations, pas de glissade ; R15 et R6).
- Les 4 kits (KAI, TARO, ZEPHYR, AKEMI) partagent la grammaire des combos : un kit associe
  chaque rôle de KAI à ses propres coups (`MoveData.luau`). Après toute retouche de dégâts,
  de vie ou de vitesse, relancer `luau tests/Balance.luau -a 4 120` (CPU contre CPU) et
  noter les chiffres dans le journal : aucun kit sous 35 % ni au-dessus de 65 % en moyenne.
- La géométrie du rig KAI vit dans `RigSpec.luau` (utilisée par le RigBuilder et les tests) :
  ne pas la dupliquer.
- Le client ne décide jamais d'un coup, de la vie ni du KO ; les effets sont cosmétiques.
- Ne jamais affirmer avoir testé dans Roblox Studio. Pas d'ID d'asset (son, animation,
  texture) inventé.
- Après chaque livraison, mettre à jour `docs/JOURNAL.md` (version, fichiers, tests,
  problèmes ouverts, prochaine étape).
