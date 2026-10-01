# Instructions pour Claude

- Lire `docs/Roblox_Guide_Claude.md` (cahier des charges) et `docs/JOURNAL.md` (état actuel)
  avant toute modification. Le propriétaire est Wilhem ; répondre en français.
- Le code est synchronisé par Rojo : `src/shared` → ReplicatedStorage.Shared,
  `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client.
  Ne jamais committer de `.rbxlx`.
- `src/shared/CombatSimulation.luau`, `src/shared/FighterAI.luau` et
  `src/shared/CinematicDirector.luau` restent purs (aucune API Roblox, aucun `require`) pour
  rester testables. Lancer `luau tests/CombatSimulation.test.luau`,
  `luau tests/FighterAI.test.luau` et `luau tests/CinematicDirector.test.luau` après chaque
  changement, et ajouter un test pour chaque règle de combat ou plan de caméra nouveau.
- Le client ne décide jamais d'un coup, de la vie ni du KO ; les effets sont cosmétiques.
- Ne jamais affirmer avoir testé dans Roblox Studio. Pas d'ID d'asset (son, animation,
  texture) inventé.
- Après chaque livraison, mettre à jour `docs/JOURNAL.md` (version, fichiers, tests,
  problèmes ouverts, prochaine étape).
