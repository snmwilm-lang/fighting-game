# Musique et sons libres de droits — mode d'emploi

La musique générée par le jeu est **supprimée**. Le jeu joue maintenant de **vraies pistes**,
que tu choisis dans Roblox Studio. Aucun ID n'est écrit dans le code : un ID inventé ne
marcherait pas, et Roblox n'accepte que l'audio hébergé sur Roblox.

## Où trouver de l'audio libre de droits

1. **Creator Store de Roblox** (le plus simple).
   - Dans Studio : *Toolbox › Audio* (onglets *Music* et *Sound Effects*).
   - Les pistes publiées par le compte **Roblox** viennent de sa bibliothèque sous licence :
     elles sont gratuites et autorisées dans les expériences Roblox.
   - Clique sur ▶ pour écouter, puis glisse la piste dans le dossier indiqué plus bas.
2. **Tes propres fichiers libres de droits.** Par exemple des packs CC0 : Kenney, OpenGameArt
   avec le filtre CC0, ou Pixabay Music.
   - Importe-les dans *Creator Dashboard › Development Items › Audio*.
   - Ensuite, crée un `Sound` dans Studio et colle l'ID dans `SoundId`.

## Où les mettre

Dans l'Explorer : **ReplicatedStorage › Audio › Music** et **ReplicatedStorage › Audio › SFX**.
Les dossiers existent déjà dans le `.rbxlx` et dans le projet Rojo. Rojo ne touche pas à leur
contenu.

- Chaque son est un objet `Sound`.
- **Son nom (`Name`) indique au jeu quand le jouer.**
- Le `Volume` du `Sound` est respecté : 0,5 à 0,7 conviennent bien.

### Musique (`Audio › Music`)

| Nom du Sound | Quand | Idée de recherche dans la Toolbox |
|---|---|---|
| `MENU` | menus, hub, sélection | « japanese lofi », « calm taiko », « menu ambient » |
| `BATTLE` | tout combat (les arènes sans piste à elles) | « epic battle », « anime fight », « intense drums » |
| `TEMPLE` | SCARLET TEMPLE | « japanese battle », « shamisen », « taiko » |
| `FROZEN` | FROZEN LAKE | « ice », « cold battle », « winter epic » |
| `NEON` | NEON ROOFTOP | « cyberpunk », « synthwave fight », « electronic battle » |
| `VOLCANO` | VOLCANO FORGE | « heavy metal battle », « inferno », « dark epic » |
| `BAMBOO` | BAMBOO DOJO | « kung fu », « dojo », « flute battle » |
| `SKY` | CLOUD PALACE | « heavenly », « orchestral epic », « sky » |
| `ASURA` | boss (ASURA, KUROEN SHIN) | « boss battle », « final boss », « dark orchestral » |
| `WRATH` | seconde vie d'ASURA | « final boss phase 2 », « choir epic », « demonic » |
| `VICTORY` | jingle : tu gagnes le match | « victory jingle », « win fanfare » |
| `DEFEAT` | jingle : tu perds le match | « defeat », « game over jingle » |

- Une piste qui manque est remplacée par une piste plus générale :
  - une arène sans piste joue `BATTLE` ;
  - `WRATH` joue `ASURA`, puis `BATTLE`.
- S'il n'y a aucune piste, il n'y a **pas de musique**.
- Les pistes bouclent et s'enchaînent en fondu. Elles baissent pendant les cinématiques et
  montent un peu dans les moments décisifs.

### Sons (`Audio › SFX`)

Un `Sound` remplace le son intégré qui porte le même nom. Les noms possibles :

- **Coups** :
  - `hit`, `heavyHit`, `swing`, `heavySwing`, `projectile` pour tous les persos ;
  - ou bien `KAI.hit`, `KAZAN.heavyHit`, etc. pour un seul perso (prioritaire sur le nom
    général).
- **Actions** : `Block`, `GuardBreak`, `Clash`, `Parry`, `Wall`, `Evade`, `Slip`, `Blink`,
  `Stance`, `SuperFlash`, `Skill`, `Prompt`, `Perfect`, `Graded`, `SuperJump`, `Bounce`, `KO`,
  `Cinematic`, `Tip`, `Knockdown`, `GetUp`, `Jump`, `Land`, `Dash`, `PassiveReady`, `Chilled`,
  `Poison`, `Armor`, `Heal`, `Reflect`, `Drone`, `Shackled`, `Domination`, `Counter`,
  `Revive`, `RoundStart`, `UiHover`, `UiClick`.

Pour commencer, les plus importants sont `hit`, `heavyHit`, `swing`, `Block`, `KO`, `Dash`,
`Jump`, `Land`, `UiClick`. Recherches utiles : « punch impact », « heavy punch », « whoosh »,
« block shield », « anime hit », « ui click ».

Sans remplacement, le jeu garde les sons intégrés du client Roblox.

## Autre méthode (dans le code)

`Music.CUSTOM` (`src/shared/Music.luau`) et `SoundPalette.CUSTOM`
(`src/shared/SoundPalette.luau`) acceptent aussi les mêmes noms, avec la valeur
`"rbxassetid://ID"`.

## Tes musiques (livrées le 5 octobre 2026)

Elles sont dans `assets/music/`, le volume égalisé (-14 LUFS) pour qu'aucune ne soit plus forte que les autres :

| Fichier | Où | Durée |
|---|---|---|
| `menu_1_be_and_obey.mp3` | lobby / menus | 4:22 |
| `menu_2_funk_break_beat.mp3` | lobby / menus | 2:11 |
| `battle_1_fast_amen_break.mp3` | combats | 1:41 |
| `battle_2_risky_step.mp3` | combats | 2:10 |

Deux morceaux par endroit forment une playlist : l'un joue jusqu'au bout, puis l'autre (jamais deux fois le même d'affilée).

**Pour les entendre dans le jeu.** Roblox ne lit que les sons envoyés sur Roblox ; je ne peux pas le faire à ta place.

1. Dans Studio : *Fenêtre › Gestionnaire d'assets (Asset Manager) › Importer*, puis choisis les 4 fichiers de `assets/music/`. Ou passe par create.roblox.com › Créations › Audio › Importer.
2. Attends la modération : quelques minutes, l'audio passe en « Approuvé ».
3. Copie l'ID de chaque son (clic droit › Copier l'ID).
4. Colle-le dans `src/shared/Music.luau`, dans `Music.TRACKS`, sous la forme `id = "rbxassetid://123456789"`.

Autre méthode, sans toucher au code : glisse les sons dans *ReplicatedStorage › Audio › Music*, dans un Folder nommé `MENU` (les 2 du lobby) et un Folder nommé `BATTLE` (les 2 de combat).

Les noms de fichiers d'origine viennent de Pixabay (berrydeep, black_kumizhi, rockot), dont la licence autorise l'usage dans un jeu. Garde quand même les pages d'origine en cas de réclamation de droits sur Roblox.
