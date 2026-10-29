# Idées de Wilhem — la boîte à idées

Tenue par l'agent `idees` (`.claude/agents/idees.md`). Une fiche par idée, numérotée `I-###`.

Statuts :
- `nouvelle` ;
- `à clarifier` ;
- `prête` (elle passe à l'agent `production`) ;
- `en production` ;
- `faite (vX.Y.Z)` ;
- `refusée (raison)`.

---

Dernier tri : 29 octobre 2026 (routine du matin, sur la v0.36.14, HEAD 4888726). Aucune idée nouvelle de Wilhem depuis le 27/10 : aucune fiche « nouvelle » à compléter. I-001 est réordonnée en fiche de production pour KUROEN SHIN ; I-004 est relue après la v0.36.14 (le CLASSÉ refusé après un chargement échoué).

## I-001 · Un FATAL FINISHER pour NOVA, KUROEN, ASURA et KUROEN SHIN
- **Date** : 12 octobre 2026 pour l'idée (v0.27.0) ; ces quatre persos attendent depuis la v0.33.0.
- **Wilhem** :
  - « une animation comme les Legendary Finish de DBL quand le fatal tue, une anime spéciale plus longue » (rappelé en tête de `Finishers.luau`) ;
  - la règle : « seulement sur la deuxième vie… si l'adversaire n'a pas peu d'HP et l'utilisateur du final n'a pas déjà un round gagné, le FATAL FINISHER s'active pas, il y a juste le fatal classique » (journal, v0.27.0).
- **Interprétation** : quand le COUP FATAL de l'un de ces quatre persos tue, le joueur voit une scène d'environ 10 s propre au perso. Cette scène est le K.O. lui-même, avec le nom du finisher.
- **Où on en est** (29 octobre 2026) : trois persos sur quatre sont faits. **Il ne reste que KUROEN SHIN, et il est prêt.** Tout ce qu'il faut à production est plus bas, dans « KUROEN SHIN · la fiche de production ».
  - **NOVA, faite (v0.36.4)** : FATAL ERROR (ERREUR FATALE), 11 s. Huit drones se rangent en rail d'anneaux devant son gantelet, puis un compte 3-2-1-0 et un seul tir ; la cible « bugue », puis tombe. « ZERO HOUR » a été écarté (décision du 17/10). Trois bugs de sa scène se suivent dans `BUGS.md` et ne rouvrent pas l'idée : B-012 (la visière dans sa tête, ouvert), B-013 et B-014 (à confirmer en jeu par Wilhem) ;
  - **KUROEN, fait (v0.36.9)** : BLACK SUN (SOLEIL NOIR), 10,7 s. Les trois marques de DOMINATION s'allument dans son dos. Trois coups (genou, coude, paume) laissent chacun un petit soleil noir sur la cible. Les trois soleils volent dans son poing levé et n'en font plus qu'un, puis AXE OF NIGHT abat la cible des deux poings. Deux points se suivent ailleurs et ne rouvrent pas l'idée :
    - ses trois coups sont ceux de sa chope, ECLIPSE CLINCH : assumé pour cette livraison, à revoir par Wilhem (`DECISIONS.md`, 22/10) ;
    - le grand soleil saute de 3,6 studs au coup mortel (B-031, cosmétique, ouvert) ;
  - **ASURA, fait (v0.36.12)** : SAMSARA (le même mot en français), 10,7 s. Produit, validé et livré le 26/10. Trois plans sont à revoir, sans bloquer : voir « ASURA · SAMSARA », plus bas ;
  - **KUROEN SHIN : rien encore.** Il joue toujours son fatal classique, 真 · ETERNAL ECLIPSE.
- **Ce qui existe pour tous** (revérifié le 29/10 sur la v0.36.14 : rien n'a bougé) :
  - **21 kits ont leur finisher** : les 20 persos jouables et ASURA. Chacun a une ligne `Finisher = { Name, Length, FinalTick }` dans `MoveData.luau` et une scène dans `Finishers.luau` (une fonction `S.KIT` dans `Finishers.build`, `:50`). Le réalisateur cherche la scène sous le nom du kit de l'attaquant (`CinematicDirector.luau:5179`) ;
  - **la règle de déclenchement** est dans `CombatSimulation` et ne change pas : un COUP FATAL qui tue, lancé par un perso qui a déjà gagné une manche (ou mis K.O. un perso d'un relais). La ligne `Finisher` se lit sur le kit de l'attaquant (`kitOf`, `CombatSimulation.luau:175-177`, utilisé en `:1330-1332`). Depuis la v0.36.8 (B-020), « qui tue » veut dire un vrai K.O. : `finish` vaut `fells`, sauf si la cible va se relever (la première vie d'ASURA, seul kit avec une seconde vie) ;
  - **les tests de `tests/Cinematography.test.luau`** :
    - le test commun de tous les finishers (`:338`) : au moins 6 plans propres au perso, un nom qui n'est celui d'aucun coup d'un autre kit, le K.O. avec son nom après le coup mortel, la cible à terre à la fin (pose `DownFace`, `:385`), des sons de la palette. Pour les sons, il lit `Palette.MATERIALS[kit] or Palette.MATERIALS.KAI` (`:386`) : un kit sans matière passe avec celle de KAI. **Ce test ne voit donc pas B-033** ;
    - chaque finisher joué dos au mur, des deux côtés (v0.36.5, `:169`), et chaque COUP FATAL classique aussi (v0.36.6) ;
    - la mesure du sujet caché par l'autre corps, `Kit.hiddenShare` (`tests/CinematicKit.luau`), et la fonction `film(kit, center, mirror, wall)` (`:598`). Elles servent aux 6 tests de placement de BLACK SUN (`:613-672`) et à ceux de SAMSARA (`:880-938`). **Un nouveau finisher n'y entre pas tout seul** : il lui faut ses propres tests ;
    - le test des noms des finishers des bosses (`:947-998`, v0.36.12). KUROEN SHIN y entrera tout seul ;
  - **le test « languages » de `tests/Lobby.test.luau`** exige la traduction du nom de chaque finisher, bosses compris (`:322`) ;
  - **les tests de `tests/CombatSimulation.test.luau`** :
    - le test « kit sans finisher » (`:1322-1351`) échouera exprès quand KUROEN SHIN aura sa ligne : voir le point 7 de sa fiche de production ;
    - le vrai défi d'ASURA (`:1377-1476`, avec ses aides `challenge`, `:1388`, et `bossFatal`, `:1419`) : ASURA contre une équipe de 3, dans ses deux vies, et jamais de finisher contre un seul perso. C'est le modèle du test de défi de KUROEN SHIN.
- **ASURA · SAMSARA, fait (v0.36.12)** :
  - **la scène** (`S.ASURA`, `Finishers.luau:3264` ; ses 12 plans composés avec `frameOn`, `:3249-3263`) : 10,7 s, coup mortel au tick 430.
    - Son dos dans l'aura noire, le sol qui se fend en X sous ses pieds, puis son visage.
    - Il jette ses quatre bras en X, et une roue d'or s'allume derrière son dos. Ses quatre poings prennent feu un à un, dans l'ordre du X ; la roue tourne à chaque battement, la lumière vire au rouge sang.
    - La cible lève sa garde. Les feux s'éteignent pendant un pas lourd, puis les quatre poings tirés aux hanches se rallument ensemble, dans le silence.
    - Ses deux paumes ouvrent la garde, ses deux poings du bas entrent dans le ventre un temps après. Le temps s'arrête.
    - La cible retombe face contre terre dans la roue gravée au sol. K.O. « SAMSARA » sur une carte noire et rouge sang, jamais « VICTORY ».
  - **le nom** (décision du 26/10) : le royaume des asuras est l'une des six voies de la roue des renaissances, le samsara. ASURA est celui qui se relève, sa cible non. Wilhem peut le renommer : une ligne de `MoveData` (`:1416`) et une de `Locale` ;
  - **ses gestes** : trois poses de scène à lui (`AsuraWheel`, `AsuraChamber`, `AsuraFourStrike`, dans `PoseLibrary`) et trois clés de `FourArms` pour la paire du bas (`spokes`, `cocked`, `converge`). Les outils de test voient maintenant ses bras du bas (`CinematicKit`, `WeaponKit`, `Storyboard`), et les storyboards dessinent chaque perso dans ses propres couleurs ;
  - **les tests** : Cinematography +10, CombatSimulation +1, Animation +1. Au pire, 7 % du sujet est caché par l'autre corps. B-033 est resté à part (décision du 26/10) ;
  - **reste à revoir, sans bloquer** (validation du 26/10) :
    - **trois plans** (`Finishers.luau:3255-3257`) :
      - `asura-ss-guard` (ticks 304 à 350, la cible lève sa garde) : ASURA est à moitié hors cadre, au bord gauche ;
      - `asura-ss-step` (ticks 350 à 372, son pas lourd) : la roue est vue par la tranche, elle ne se lit plus ;
      - `asura-ss-draw` (ticks 372 à 420, les quatre poings tirés aux hanches qui se rallument) : une plongée de 46°, et deux de ses quatre poings sont à moitié cachés par son propre corps. C'est le temps « les quatre à la fois » : on doit voir les quatre ;
    - **qui s'en charge** : production, dans une petite livraison à part. Seuls l'angle et le cadre de ces trois plans changent, et le test de la scène et ses 6 tests de placement doivent repasser, des deux côtés. Ou bien Wilhem, s'il préfère les refaire d'après une planche. Rien ne l'attend. Ces plans ne sont pas dans `BUGS.md` : ils se suivent ici ;
    - **B-033** (ouvert) : en combat, et pour le coup mortel que porte la simulation dans sa scène, ses coups sonnent comme ceux de KAI (`MoveKit`). Les sons que joue la scène elle-même sont bien les siens ;
    - **B-040** (ouvert, passé de cosmétique à mineur par la chasse du 27/10) : aux ticks 464 et 470 (plan `asura-ss-blown`, `Finishers.luau:3329-3335`), la cible bascule au sol en deux temps (`Launched`, `DownImpact`, puis `DownFace`), et la caméra du plan, composée sur son corps, saute de 7 studs avec elle. La même bascule est dans 15 autres finishers et dans la scène K.O. de fin de match des 22 persos ;
    - **deux trous dans les tests**, relevés par la validation : un nom égal à un texte qui existe déjà passerait le test des noms ; et la cible n'est jamais placée au-delà de x = 25,3 près du mur. Ils comptent pour KUROEN SHIN (voir « Pour chaque nouvelle scène ») ;
    - rien n'est vu dans Studio, en particulier l'or de la roue sur l'aura noire de sa seconde vie ;
  - **les retours de Wilhem sur ses bras**, à garder pour toute retouche (journal v0.15.1, v0.16.1 et v0.23.20) : « les deux autres bras d'ASURA sortent des côtés normalement » ; « travaille les 4 bras d'ASURA, c'est dégueulasse » ; « ce bug avec les bras d'ASURA, les bras du bas se lèvent, règle-le » (capture en cinématique) ; « ASURA, ses bras, la deuxième paire, rends-la agréable ». Les bras du bas ne montent pas devant son visage et ne passent jamais dans son corps (test Animation, pour toute pose de `FourArms.SCENE`). Deux autres règles de Wilhem tiennent pour lui : chacun de ses coups a sa propre pose (« chaque animation est obligatoirement différente ») ; ses deux victoires viennent des images d'Asura's Wrath qu'il a envoyées (« tu peux alterner les deux »), et elles restent à la fin du match, jamais dans un finisher. En jeu, le client lisse leurs mouvements (`AnimationController:swingFourArms`, 0,1 à 0,25 s de retard) ; depuis la v0.36.12, les outils de test aussi ;
  - la préparation d'avant la production (son identité, ses ultimes à ne pas recopier, ses noms, ses pièges, sa seconde vie) a servi. Elle reste dans l'historique du dépôt : `git show 8c1c308:docs/IDEES.md`.
- **Pour chaque nouvelle scène, ce qu'ont appris les livraisons** (il ne reste que celle de KUROEN SHIN) :
  - passer le test « dos au mur, des deux côtés » (v0.36.5, B-011, B-010). Pour la voir ainsi : `luau tests/Storyboard.luau -a KIT Fatal - 1 20 wall-left`, puis `wall-right` ;
  - prévoir le placement dès le départ avec `room` (`Finishers.luau:44-48`), comme SHIN, KUROEN et ASURA : près d'un mur, toute la scène recule, jamais le perso seul. Sans `room`, la caméra d'un gros plan tombe dans un corps, ou un visage est caché aux deux tiers (B-018) ;
  - garder les deux corps sur le sol de combat, x de -28 à 28 : 11 finishers sur 19 en sortaient (B-015), surtout quand **la cible** est près du mur. `room` sert aussi à ça ;
  - `Kit.hiddenShare` : **jamais plus d'un quart du sujet caché**, à chaque image, au centre des deux côtés, dos à chaque mur et la cible près de chaque mur. Les modèles : BLACK SUN (au pire 22 % caché) et SAMSARA (au pire 7 %). La mesure se fait sur le rig KAI du labo, et les vrais avatars n'ont pas sa taille (B-018) : garder de la marge ;
  - la jouer aussi **depuis la droite**, au centre : le labo ne joue que depuis la gauche. Un plan où le perso se retourne doit avoir un angle qui dépend du côté (B-019) ;
  - poser les formes sur les vraies pièces du corps, par exemple `P(A, "RightHand")`, et non sur des nombres mesurés sur le rig du labo (B-013). Un trait posé sur une tête doit bien en sortir (B-012) ;
  - au plus une lumière allumée à la fois (B-014) ;
  - jamais « VICTORY » ni de pose de victoire (B-026) : en relais, un finisher peut tomber sans finir le match, et le perso suivant entre après la scène ;
  - **depuis BLACK SUN (v0.36.9)** : ne reprendre aucune chope ; aucun objet qui saute à l'impact (B-031). Toute forme qui traverse le coup mortel part d'une vraie pièce et voyage sans saut ; chacune porte un `mark`, et le test les suit **toutes** ;
  - **depuis SAMSARA (v0.36.12, validation du 26/10)** :
    - garder le sujet entier dans le cadre, des deux côtés. Dans `asura-ss-guard`, ASURA est à moitié hors cadre, et aucun test ne l'a vu : seule la planche le montre ;
    - une forme plate (une roue, un sceau, un disque) filmée par la tranche ne se lit plus : c'est `asura-ss-step` ;
    - une forte plongée cache les membres derrière le corps : à 46° (`asura-ss-draw`), deux poings d'ASURA sont à moitié cachés par son propre corps. `Kit.hiddenShare` ne mesure que ce que cache **l'autre** corps ;
    - la cible finit face contre terre (`DownFace`, exigé par le test commun), mais sans se retourner d'un coup au milieu d'un plan. C'est B-040, confirmé par la chasse du 27/10 : 16 finishers sur 21 font cette bascule de plus de 4 studs en une image, 19 dépassent 2 studs, et la scène K.O. de fin de match des 22 persos la fait aussi. Quand le plan est composé sur le corps de la cible, la caméra saute avec elle (7 studs dans `asura-ss-blown`). La cible tombe directement face contre terre, ou le passage de `DownImpact` à `DownFace` tombe sur une coupe. Si production corrige d'abord B-040 par une règle de l'animateur (sa piste 1), la nouvelle scène en profite d'office ;
    - jouer aussi la cible **au plus près du mur** : les placements « cible près du mur » de BLACK SUN et de SAMSARA ne la mettent jamais au-delà de x = 25,3, et le sol va jusqu'à 28 ;
    - le test des noms des bosses laisse passer un nom **égal** à un texte qui existe déjà (un thème de la boutique, une provocation) : vérifier à la main que le nom n'est pas déjà une clé de `Locale` avant de l'y ajouter.
  - **depuis la chasse du 27/10 (B-041, TOXIC FEAST de VENOM)** :
    - un plan qui tient, composé avec `frameOn` sur un corps, saute avec ce corps s'il change de place d'un coup. Après chacune de ses trois frappes, VENOM passe de sa place de frappe à sa ronde en une image (6 à 9 studs), et la caméra saute de 1,6 à 5,2 studs, dans le même plan. Un perso qui disparaît et réapparaît ailleurs le fait sur une coupe, ou caché (`a.hidden = true`, comme SHIN entre ses coupes), et le plan qui tient se compose sur des points fixes ;
    - la mesure proposée par la chasse (B-040, piste 4) : dans un même plan, la tête de la cible ne saute jamais de plus de 2 studs d'une image à l'autre, et la caméra jamais de plus de 1,5 stud.
- **KUROEN SHIN · la fiche de production** (préparée le 24/10 ; relue ligne par ligne et réordonnée le 29/10, sur la v0.36.14, HEAD 4888726. La version du 28/10 reste dans l'historique du dépôt : `git show 4888726:docs/IDEES.md`) :
  1. **Où brancher la scène** :
     - `MoveData.luau` : son kit `:1419-1447` (`kit("KUROEN SHIN", …)` en `:1427`), sans ligne `Finisher`. La ligne s'ajoute sur **son** kit, comme celle d'ASURA (`:1416`). Il ne prend pas celle de KUROEN : BLACK SUN reste à KUROEN seul ;
     - ce que la simulation porte au coup mortel : ses rôles sont ceux de KUROEN (`Roles = table.clone(base.Roles)`, `:1430`). Son COUP FATAL est donc `KuroenFatal` (蝕 · TOTAL ECLIPSE dans `MoveData`, `:785`, 300 de jauge), affiché sous le nom de son thème. À côté : sa DOMINATION (`:1437-1438`), son titre de PORTE, 真 · TRUE EMPEROR (`:1444`), sa chope à lui (`Throws["KUROEN SHIN"]`, `:1573-1576`), et `MoveKit`, qui ignore les bosses (`:1460-1474`, la règle en `:1463`) ;
     - `Finishers.luau` : rien pour lui. **Son nom contient une espace** : sa scène s'écrit `S["KUROEN SHIN"] = function(ctx, frame, a, d, tick, dir)` dans `Finishers.build` (`:50`), et non `function S.KUROEN SHIN`. C'est sous ce nom exact que le réalisateur la cherche (`cin.kit`, `CinematicDirector.luau:5179`). `room` est en `:44-48`. Les modèles les plus proches : `S.KUROEN` (`:3021`) et `S.ASURA` (`:3264`, ses plans `:3249-3263`) ;
     - `CombatSimulation.luau` : rien à changer. Il n'a pas de seconde vie, et ses cibles non plus : `finish` vaut `fells` (B-020) ;
     - `CinematicDirector.luau` : son thème, `GEN.add("KUROEN SHIN")` (`:4928-4941`). Son FATAL : 真 · ETERNAL ECLIPSE, archétype `pillar` (des piliers de lumière appelés du ciel sur la cible, de loin), ouverture `emerge` (il sort du sol, dans son sceau), fin `skyward` (un uppercut envoie la cible vers le ciel) ;
     - autour : son CPU (`ultimate = 1`, `FighterAI.luau:75-77`), ses couleurs et celles d'ÉCLIPSE DIVINE (`CharacterData.luau:211-212`), sa garde (`PoseLibrary.luau:1496-1497`), ses effets de combat (`KitFX.luau:138`) ;
     - le défi : le boss est l'équipe 2, qui commence à droite (`Sim.setTeams(world, request.team, { GameModes.find(mode).boss })`, **`init.server.luau:687`** depuis la v0.36.14, au lieu de `:676`) ;
     - les outils : les storyboards le dessinent dans ses couleurs (TRUE EMPEROR), la cible en KAI (`Kit.characters`, v0.36.12). Il n'a ni arme ni bras en plus : **aucun outil à étendre**, ils le dessinent avec le corps de KAI, comme KUROEN. Sa planche demande des guillemets : `luau tests/Storyboard.luau -a "KUROEN SHIN" Fatal - 1 20`, puis la même avec `right`, `wall-left` et `wall-right` en dernier argument.
  2. **Son identité** :
     - 真, « KUROEN au-delà de toute limite » (sa description, `Locale`). Wilhem le voulait « cassé comme Gogeta » (journal, v0.17.0 ; « like Gogeta in FighterZ » en tête de son kit), et le plus fort des deux bosses (« SHIN », journal, v0.23.22). C'est le boss du CHALLENGE · KUROEN SHIN, jamais jouable (il n'est pas dans `KitOrder`) ;
     - blanc et or : cheveux blancs à pointes d'or, yeux d'or, gilet et chemise blanc cassé (F4F0E6) bordés d'or, pantalon noir, ki FFE9A0. Il n'a qu'un style, TRUE EMPEROR ;
     - son allure : debout et calme, les mains basses et ouvertes, « no guard to keep » (`PoseLibrary.luau:1496`). Il ouvre ses ultimes en lévitation (`Levitate`), et entre en scène debout (`StandTall`) ;
     - ce qui le rend « cassé » : l'INSTINCT DIVIN (le premier coup qui l'atteint est esquivé, et il réapparaît dans le dos de l'attaquant ; une charge, de retour toutes les 8 s), un dash qui traverse les coups (« transmission instantanée »), et la DOMINATION née en ÉCLIPSE (niveau III), qui ne se perd jamais. Son thème le résume : « il est derrière toi avant que tu le voies » ;
     - la scène doit se lire « KUROEN au-delà de toute limite » : des poings, des coudes, des genoux, l'empereur, le calme. Elle ne doit pas se lire « ange » ou « lumière » ;
     - une piste, pas une consigne : ce qu'aucune de ses scènes ne montre encore, c'est l'INSTINCT DIVIN (le coup esquivé, lui déjà dans le dos) et son calme (les mains basses, sans garde). Le montrer mène au piège de B-041 (point 5).
  3. **Ce qu'il ne faut pas recopier** :
     - **ses ultimes** (`GEN.add("KUROEN SHIN")`) :
       - R, 真 · DIVINE EMPEROR RUSH : la cible tirée vers lui à chaque coup (`pull`) ;
       - ÉVEIL, 真 · ZERO ABSOLU: TRUE ECLIPSE : une tempête de poings de tous les côtés, avec ses images fantômes (`gatling`, ouverture `clones`) ;
       - PORTE, 真 · TRUE EMPEROR : il tourne autour de la cible plus vite que l'œil (`orbit`) ;
       - FATAL, 真 · ETERNAL ECLIPSE : il sort du sol, des piliers de lumière tombent du ciel sur la cible, un uppercut l'envoie en l'air (`pillar`, `skyward`) ;
     - **sa chope** : la cible soulevée d'une main par la gorge, le ki pulse deux fois, la paume qui l'envoie (`MoveData.Throws`) ;
     - **ses effets de thème tels quels** : `divineFist`, `divineHalo` et `divineSeal` (`CinematicDirector.luau:4939`) ne sont que d'autres noms d'effets du jeu (`CinematicController.luau:277` : `rageFist`, `dragonHelix`, `seal`). Le poing et le sceau sont ceux de KUROEN (`crimsonFist`, `eclipseSeal`, `:276`) : repris seuls, c'est encore KUROEN en blanc ;
     - **ceux de KUROEN, dont il reprend les coups** :
       - BLACK SUN : les trois marques qui s'allument dans le dos, trois coups (genou, coude, paume), trois petits soleils, AXE OF NIGHT des deux poings ;
       - sa chope ECLIPSE CLINCH (genou, coude, paume) ;
       - son R (des coups de tous les côtés, de plus en plus vite), son ÉVEIL (la lumière s'éteint, une éclipse rouge dans le ciel), sa PORTE (une tempête de poings), son FATAL (le jonglage sous l'éclipse) ;
     - **SAMSARA**, un autre perso mais le même or : ni la roue, ni des poings qui prennent feu un à un ;
     - **FINAL MERCY d'ELIAN** : la paume, le pilier, sept auréoles, le blanc, la croix, des ailes. Et la PORTE de RAIJIN, qui appelle des piliers de foudre.
  4. **Les noms et les mots à éviter** (comptés le 29/10 sur `Locale`, 1 626 textes. Les 6 textes ajoutés par la v0.36.14, sur le serveur réservé et le CLASSÉ refusé sans sauvegarde, n'ont aucun mot de sa famille : les comptes ne bougent pas) :
     - **les 21 finishers** : MAXIMUM KAIENHA, DEMPSEY ROLL: FINAL ROUND, GALE EXCALIBUR, THOUSAND SHADOWS, TEN FISTS OF RAGE, FINAL DIVISION, INVERTED WORLD, THRONE OF RUINS, SPEAR OF THE THUNDER GOD, FROZEN REQUIEM, TOXIC FEAST, TITAN QUAKE, STELLAR COLLAPSE, RESONANCE, CAGE OF CLAWS, CRIMSON COVENANT, THE GREAT HUNT, FINAL MERCY, FATAL ERROR, BLACK SUN, SAMSARA ;
     - **les siens** : 真 · DIVINE EMPEROR RUSH, 真 · ZERO ABSOLU: TRUE ECLIPSE, 真 · ETERNAL ECLIPSE, 真 · TRUE EMPEROR, TRUE DOMINATION (son passif), DIVINE INSTINCT, son style TRUE EMPEROR, les titres du défi (GOD SLAYER, ECLIPSE BREAKER, TRUE EMPEROR'S EQUAL, TRUE EMPEROR), les succès GOD SLAYER et TRUE EMPEROR, la provocation « ECLIPSED 🌑 » ;
     - **ceux de KUROEN** : ses 29 coups (dont AXE OF NIGHT, RISING UPPER, CROWN BREAKER, FALLING EMPEROR, SOVEREIGN UPPER, TYRANT'S FIST, EMPEROR'S DECREE, ECLIPSE BREAKER, CRIMSON STEP, EMPEROR RUSH, 零 · ZERO ABSOLU: ECLIPSE, 皇 · EMPEROR'S GATE, 蝕 · TOTAL ECLIPSE), EMPEROR STEP, DOMINATION, BLACK SUN, ses styles (EMPEROR, BLOOD MOON, DIVINE ECLIPSE) ;
     - **refusés d'office par le test des noms des bosses** : il refuse tout mot de 4 lettres ou plus déjà présent dans plus de deux textes (`Cinematography.test.luau:988-993`). Dans sa famille : ECLIPSE (19 textes), FINAL (15), DIVINE (14), EMPEROR (11), LIGHT (9), LAST (9), ZERO (8), INSTINCT (6), TRUE (5), HEAVEN (5), PALM (5), KING (5), BLACK (4), THRONE (4), GOLD (3), JUDGMENT (3). Et des mots de combat qu'on pourrait vouloir : SHADOW (14), BLOW (13), FIST (12), STEP (11), STRIKE (11), WRATH (5), VOID (3), HOLY (3). INSTINCT est refusé aussi : le geste peut montrer l'INSTINCT DIVIN, pas le nom ;
     - **ce que ce test ne voit pas, à vérifier à la main** :
       - les mots de 3 lettres : GOD (déjà dans GOD SLAYER, GOD SLAIN 👑 et SPEAR OF THE THUNDER GOD), SUN (BLACK SUN), SKY (3 textes) ;
       - un nom **égal** à un texte qui existe déjà : le test l'accepte (`text == name`, `:985`). Par exemple les thèmes de la boutique (GOLD, PHANTOM, INFERNO, SAKURA, ABYSS), d'autres textes d'un seul mot (HALO, SACRED, CELESTIAL, ASCENSION, AWAKENED, STILL, SKY, EMPEROR, THRONE, PALM, INSTINCT, JUDGMENT) ou une provocation ;
     - **la règle de production** (décision du 22/10, pour BLACK SUN) : pas de nom en ECLIPSE, EMPEROR, DIVINE, TRUE ou ZERO, et pas de kanji (aucun finisher n'en a). Son nom entre dans `Locale.FR`, ou dans `Locale.SAME` s'il ne change pas en français ; sinon « languages » échoue. Pour le changer ensuite : une ligne de `MoveData` et une de `Locale` ;
     - pour information, sans consigne : des mots qu'aucun texte n'a encore le 29/10 : BEHIND, CALM, UNSEEN, AFTERIMAGE, MIRAGE, GLIMPSE, REIGN, ZENITH, NOON, MIDNIGHT, LIMIT. À recompter au moment du choix ;
     - **B-034** (ouvert, attend Wilhem, ne bloque pas) : le COUP FATAL de KUROEN, celui qu'il emprunte, porte le nom de la PORTE de DAICHA, « 蝕 · TOTAL ECLIPSE » (`MoveData.luau:785` et `:617`). Pour lui, rien ne change à l'écran : son thème affiche son FATAL sous son propre nom. Si KUROEN est renommé avant sa scène, ce nouveau nom s'ajoute à la liste. Le test des noms des bosses n'échoue pas sur ce doublon (il ne lit que les finishers des bosses).
  5. **Les pièges** :
     - **son double, ÉCLIPSE DIVINE** :
       - le style ÉCLIPSE DIVINE de KUROEN, gagné en battant KUROEN SHIN, a **exactement** ses couleurs (`CharacterData.luau:211-212`). Et BLACK SUN prend le ki du style (`ctx.characters[A].Energy`). Un joueur en ÉCLIPSE DIVINE joue donc déjà un BLACK SUN blanc et or, avec le visage de KUROEN SHIN ;
       - sa scène doit se distinguer de BLACK SUN **par ses gestes et son déroulé**, pas seulement par ses couleurs ;
     - **son INSTINCT DIVIN et la caméra (B-041)** :
       - s'il esquive et réapparaît dans le dos de la cible, sa réapparition tombe sur une coupe, ou se fait caché (`a.hidden = true`, comme SHIN entre ses coupes, `Finishers.luau:176` ; ZEPHYR et AKEMI le font aussi, `:758` et `:973`) ;
       - jamais dans un plan composé avec `frameOn` sur lui : la caméra sauterait avec lui, comme avec VENOM (1,6 à 5,2 studs en une image). Le plan qui tient pendant qu'il disparaît se compose sur des points fixes (la cible, sa place d'arrivée) ;
     - **la chute de la cible (B-040)** :
       - le test commun exige la cible face contre terre à la fin (`DownFace`). Mais `FATAL.fall` (`CinematicDirector.luau:2689-2698`), qu'appellent 19 scènes de `Finishers`, passe de `Launched` à `DownFace` d'une image à l'autre : 130 à 174° d'un coup. La caméra d'un plan composé sur la cible saute avec elle (7 studs dans `asura-ss-blown`) ;
       - ne pas l'appeler tel quel dans un plan qui tient. La cible tombe directement face contre terre (jetée vers l'avant), ou le passage à `DownFace` tombe sur une coupe ;
       - si production corrige d'abord B-040 dans l'animateur (sa piste 1), la scène en profite d'office ;
     - **sa DOMINATION est déjà au niveau III** (`Start = 3`, `NoLoss` ; pack : « comme KUROEN, en or »). Allumer les trois marques une à une, comme BLACK SUN, n'aurait pas de sens pour lui : elles sont déjà allumées ;
     - **la couleur** :
       - le blanc et la lumière sont aussi à ELIAN. Le pack donne à KUROEN SHIN les plumes d'ELIAN (`FEATHER_2x2`) ;
       - le mesh d'aile (`WING`) est prévu pour ELIAN et pour lui, mais il n'a pas d'ID (`VfxConfig.luau:151` : 0). Il n'est donc pas utilisable ;
       - un pilier de lumière est déjà pris deux fois, par son propre FATAL et par FINAL MERCY ;
       - l'or FFD23F est celui d'ASURA (SAMSARA compris), de KAI en SACRÉ et en ÉVEILLÉ, et du thème OR de la boutique ;
       - décision du 15/10 : le K.O. et l'aura FATAL gardent les effets du jeu, pas ceux du pack VFX ;
     - **en défi, il joue depuis la droite** (il est l'équipe 2) : les planches et les tests depuis la droite comptent autant que les autres ;
     - **la cible** est l'un des 20 persos jouables, avec son arme s'il en a une. Les outils prennent KAI : garder de la marge (B-018) ;
     - **son INSTINCT DIVIN dans les tests** : dans son test de défi, seul lui frappe, comme dans celui d'ASURA. Si la cible doit le toucher, mettre son esquive de côté comme les tests de B-020 (`d.evadeCharges, d.evadeCharge = 0, 1e9`, `CombatSimulation.test.luau:1878`) ;
     - **la scène sera rare**, comme celle d'ASURA. Il faut, à la fois : un défi à 2 ou 3 persos, dont un déjà mis K.O. par lui ; sa vie sous 30 % (900 PV sur 3 000) ; son COUP FATAL pas encore utilisé (un par match) ; un coup qui tue. Le CPU lance son COUP FATAL dès qu'il est prêt (`ultimate = 1`).
  6. **Sa matière sonore (B-033) : la faire dans la même livraison** (recommandé) :
     - **aujourd'hui** (revérifié le 29/10 : `SoundPalette`, `SoundController` et `CinematicController` n'ont pas changé) : il n'a pas d'entrée dans `SoundPalette.MATERIALS` (`SoundPalette.luau:57`), et `material(kit)` rend alors celle de KAI (`SoundController.luau:32-34`). En combat, ses élans, ses pas et les temps de sa chope sonnent comme KAI (`:237`, `:182`), ses coups comme KUROEN (`MoveKit`, `:186`) ;
     - **dans sa scène, ce serait pire que pour ASURA** : les sons que la scène joue elle-même (`whoosh`, `heavy`) prennent le kit de l'attaquant (`cin.kit`, `CinematicController.luau:760`, joué en `:604` ; `SoundController:cinematicSound`, `:137-147`), donc ceux de KAI pour lui. Le coup mortel que porte la simulation (`KuroenFatal`) sonne comme KUROEN. Sa scène sonnerait KAI et KUROEN, jamais lui. Les sons communs (`boom`, `charge`) ne dépendent d'aucun kit ;
     - **pourquoi ensemble** : la question de sa matière se règle une fois, pour la scène et pour le combat. Livrer la scène seule, c'est livrer une scène qui sonne comme deux autres persos, et aucun test ne le dirait (le test commun accepte la matière de KAI, `Cinematography.test.luau:386`) ;
     - **la piste de B-033** :
       - une entrée `["KUROEN SHIN"]` faite de **nouvelles tables**, par exemple celles de KUROEN, un peu plus graves, en salle (comme ASURA par rapport à KAI). Jamais `MATERIALS["KUROEN SHIN"] = MATERIALS.KUROEN` : `SoundController.new` range chaque liste sous `kit .. "." .. part` (`:45-49`), et une table partagée prendrait le nom du dernier kit parcouru ;
       - le choix de la matière dans une fonction pure de `SoundPalette` (par exemple `materialOf(kit, moveKit, isBoss)`), testée, et appelée par `SoundController` en `:182`, `:186`, `:198` et `:237` (l'événement `Projectile` porte déjà `attacker`, `CombatSimulation.luau:1032`) ;
       - les vérifications de `Kits.test` (`:508-513` et `:535-547`) étendues aux bosses. Attention à « hits like » (`:541`) : il compare le premier son de `hit` (fichier, vitesse, bus). Celui de KUROEN SHIN doit différer de ceux de KUROEN et d'ASURA ;
       - pas d'acier (`slash`) : il frappe des poings. Aucun ID nouveau : seulement les fichiers de `CLIENT_SOUNDS` et les bus existants ;
     - **ASURA** : la même fonction corrige aussi son côté de B-033 (ses 29 coups sonnent comme KAI). Sa matière existe déjà : seule la règle change. Production choisit de le faire en même temps ou non, et le note ;
     - si production garde le repli sur KAI, elle le note dans `DECISIONS.md`, et B-033 reste ouvert.
  7. **Le test « kit sans finisher » : il échouera exprès, puisqu'il sera le dernier** :
     - **où il est** : à la fin du test « FATAL FINISHER: only a killing COUP FATAL from a fighter who already won a round; else the classic fatal » (`CombatSimulation.test.luau:1269`), lignes `:1322-1351`. Il cherche le premier kit sans ligne `Finisher`, les jouables d'abord, les bosses ensuite. Aujourd'hui, c'est KUROEN SHIN, le seul ;
     - **ce qui arrivera** : quand KUROEN SHIN aura sa ligne, il ne trouvera plus personne, et tout ce test échouera sur « no kit left without a finisher: this check has nothing to play » (`:1351`). C'est voulu : le test refuse de tourner à vide ;
     - **ce qui doit rester testé** : « un kit sans finisher joue le fatal classique, manche gagnée ou non ». La règle compte encore pour tout perso ou boss ajouté plus tard ;
     - **la nouvelle forme proposée** : `Sim.newWorld` reçoit `MoveData` en paramètre, et tout ce que la règle lit passe par `world.moveData.Kits` (`CombatSimulation.luau:111-116`, `setKits` en `:130`, `kitOf` en `:175-177`). Le test construit donc son monde sur une **copie** de `MoveData` où un kit n'a plus de ligne `Finisher`. `MoveData.Kits` et chaque kit sont gelés (`table.freeze`) : il faut `table.clone` de `MoveData`, de `MoveData.Kits` et du kit choisi, puis `Finisher = nil` sur la copie du kit, `Sim.newWorld(Config, copie, false)` et la même mise en place que `fatalWorld` (`:1130`). Il vérifie le fatal classique, manche gagnée (`start.finish and not start.finisher`, durée `Length + FinishExtra`) ;
     - **deux gardes** : la copie a bien un kit sans ligne (le test ne tourne jamais à vide) ; le vrai `MoveData` n'est pas touché, et tous ses kits ont leur ligne, KUROEN SHIN compris ;
     - **à noter** : le commentaire du test (`:1322-1324`) est mis à jour, et le changement est noté dans `DECISIONS.md`. Le test n'est jamais supprimé en silence. Production choisit la forme exacte : quel kit, ou chacun tour à tour.
  8. **Les fichiers et les commandes** :
     - **à toucher** :
       - `MoveData.luau` (sa ligne `Finisher`), `Finishers.luau` (`S["KUROEN SHIN"]`), `Locale.luau` (le nom), `PoseLibrary.luau` s'il a des poses de scène à lui ;
       - `tests/Cinematography.test.luau` (sa scène, ses placements, ses mesures), `tests/CombatSimulation.test.luau` (son défi, le test « kit sans finisher ») ;
       - avec B-033 : `SoundPalette.luau`, `SoundController.luau` (client) et `tests/Kits.test.luau` ;
       - `CombatConfig.luau` (la version), `docs/JOURNAL.md`, `docs/DECISIONS.md`, `docs/BUGS.md` (B-033) ;
     - **à lancer** : les 9 suites ; la planche au centre, depuis la droite et dos à chaque mur, puis `python3 tools/storyboard.py` ; s'il a des poses nouvelles, `luau tests/AnimQuality.luau -a all` et `luau tests/AnimPops.luau -a 50 list` ; la place (`python3 tools/build_place.py`). Aucun dégât ni aucune vie : pas d'équilibrage.
- **Persos et systèmes touchés** :
  - faits : NOVA (drones et gantelets, orange FF8A2A), KUROEN (éclipse rouge et noire, E0102E), ASURA (KAI à quatre bras, boss, or FFD23F) ;
  - reste KUROEN SHIN (boss, blanc et or) : les cinématiques (sa scène), le son (B-033), les tests. Les fichiers sont au point 8 de sa fiche ;
  - pour les trois plans d'ASURA : `Finishers.luau` seulement, avec ses tests ;
  - aucun dégât ni aucune vie : pas d'équilibrage.
- **Valeur / effort** : forte / gros pour l'idée entière, une scène par livraison.
  - KUROEN SHIN : valeur moindre, car sa scène sera rare. Effort : celui de KUROEN, plus le test « kit sans finisher » à refaire, plus B-033 s'il passe avec lui.
  - Les trois plans d'ASURA : petit effort.
- **Risques** :
  - les bosses ne déclenchent leur finisher qu'en relais, avec leur vie sous 30 % et leur COUP FATAL prêt. Un boss n'est jouable nulle part, même au labo : sa scène se verra rarement en combat, et surtout sur les storyboards ;
  - KUROEN SHIN reprend les coups de KUROEN, et KUROEN en ÉCLIPSE DIVINE joue déjà BLACK SUN dans ses couleurs : sa scène doit se distinguer par ses gestes ;
  - sans B-033, sa scène sonnerait comme KAI et KUROEN, jamais comme lui ;
  - montrer son INSTINCT DIVIN (il réapparaît dans le dos) mène droit au saut de caméra de B-041, si la réapparition se fait dans un plan composé sur lui ;
  - son nom : la plupart des mots de sa famille sont usés, et le test les refuse ;
  - décision du 15/10 : le K.O. et l'aura FATAL gardent les effets du jeu, pas ceux du pack VFX.
- **Questions ouvertes** : aucune qui bloque. Production propose le nom et la mise en scène de KUROEN SHIN, comme pour NOVA, KUROEN et ASURA. Wilhem pourra les faire refaire d'après ses planches, comme SHIN, TARO, KAI et ZEPHYR en v0.32.0. Pour Wilhem, sans bloquer :
  1. A-t-il une planche ou un nom en tête pour KUROEN SHIN, ou veut-il renommer FATAL ERROR, BLACK SUN ou SAMSARA ? Choix : a) oui, il l'envoie et production la suit ; b) non, production propose. **Recommandation : b)**, une scène se change ensuite comme les autres.
  2. BLACK SUN reprend les trois coups de la chope de KUROEN (genou, coude, paume). Choix : a) on garde ; b) production les change (avec une nouvelle validation). **Recommandation : a)**, sauf s'il trouve en jeu que la scène ressemble trop à la chope. Elle filme ces coups en gros plan avec les soleils noirs, et ne reprend ni l'éclipse, ni le jonglage, ni la tempête de poings.
  3. Comment voir les scènes des bosses, qu'aucun joueur ne peut lancer au labo ? Choix : a) sur les storyboards envoyés avec la livraison ; b) avec un bouton du labo réservé à l'accès développeur (une autre idée, à ranger à part). **Recommandation : a)**, comme pour SAMSARA.
- **Critères d'acceptation** :
  - pour chaque perso :
    - sa ligne `Finisher` dans `MoveData.luau` et sa scène dans `Finishers.luau`, avec son plan K.O. et le nom de son finisher ;
    - quand son COUP FATAL tue et qu'il a déjà gagné une manche, la scène remplace le fatal classique. Sinon, le fatal classique joue, inchangé ;
    - un seul K.O. et une seule fin de manche. En relais, le perso suivant entre après la scène ;
    - jamais « VICTORY » (B-026) ;
    - le nom du finisher a sa traduction dans `Locale.luau` ;
    - les plans sont composés avec `frameOn` ;
    - le storyboard est vérifié au centre et dos au mur (`luau tests/Storyboard.luau -a KIT Fatal - 1 20`, puis avec `wall-left` et `wall-right`) ;
    - les sons ne viennent que de `SoundPalette`, et chaque perso garde sa matière sonore ;
    - le test commun des finishers et le test « dos au mur, des deux côtés » passent (`Cinematography`) ;
    - un test avec `Kit.hiddenShare` vérifie qu'à aucune image plus d'un quart du sujet n'est caché par l'autre corps : au centre des deux côtés, dos à chaque mur, et la cible près de chaque mur ;
  - **NOVA, KUROEN et ASURA : remplis.** Pour ASURA (v0.36.12, validé le 26/10) : sa ligne sur son kit et `S.ASURA`, MAXIMUM KAIENHA inchangé ; ses quatre bras font autre chose que ses ultimes et sa chope, jamais dans son corps ; les outils voient ses bras du bas ; le vrai défi testé (ses deux vies, et jamais de finisher contre un seul perso) ; la scène vérifiée des deux côtés ; toutes ses formes suivies, sans saut ; son nom testé ; les sons de sa scène dans sa matière ; le test « kit sans finisher » joue KUROEN SHIN et passe. Ses trois plans à revoir ne sont pas des critères : ils se suivent plus haut ;
  - **pour KUROEN SHIN, en plus** :
    - **la scène** :
      - sa ligne `Finisher` est sur son kit, et sa scène est `S["KUROEN SHIN"]`. BLACK SUN et SAMSARA ne changent pas : leurs tests passent sans retouche ;
      - elle ne reprend rien de la liste « ce qu'il ne faut pas recopier » (point 3) : ni sa chope (la gorge, d'une main), ni celle de KUROEN (genou, coude, paume) ; ni les étapes de BLACK SUN (les marques qui s'allument, les trois soleils, AXE OF NIGHT des deux poings) ; ni ses ultimes (la cible tirée vers lui, la tempête de poings, le tour autour d'elle, les piliers de lumière) ; ni la roue de SAMSARA ; ni les ailes, les auréoles et le pilier de FINAL MERCY ;
      - sur la planche, elle se distingue de BLACK SUN joué en ÉCLIPSE DIVINE par ses gestes et son déroulé, pas seulement par ses couleurs ;
    - **le défi** : un test joue le vrai défi, KUROEN SHIN contre une équipe de 3. Il met le premier perso K.O., puis son COUP FATAL tue le deuxième : la scène joue, sans VICTORY, et le troisième entre après elle. Contre un seul perso, jamais de finisher ;
    - **les placements** : la scène est vérifiée depuis la droite autant que depuis la gauche (au centre, dos à chaque mur, storyboard). Un placement de plus : la cible au plus près du mur (au-delà de x = 25,3), des deux côtés, avec les mêmes exigences (corps sur le sol, caméra, au plus un quart du sujet caché) ;
    - **les leçons de SAMSARA**, vues sur la planche des deux côtés :
      - lui toujours entier dans le cadre quand il est le sujet (`asura-ss-guard`) ;
      - aucune forme plate (un sceau, une auréole, un disque) filmée par la tranche (`asura-ss-step`) ;
      - ses mains lisibles : pas de forte plongée qui les cache derrière son propre corps (`asura-ss-draw`, 46°), ce que `Kit.hiddenShare` ne mesure pas ;
    - **rien ne saute à l'écran** :
      - la cible ne se retourne pas d'un coup au sol au milieu d'un plan (B-040) : elle tombe directement face contre terre, ou le passage de `DownImpact` à `DownFace` tombe sur une coupe. Mesuré : dans un même plan, sa tête ne saute jamais de plus de 2 studs d'une image à l'autre après le coup mortel ;
      - dans un même plan, la caméra ne saute jamais de plus de 1,5 stud d'une image à l'autre, et KUROEN SHIN ne change jamais de place d'un coup à l'écran : une réapparition tombe sur une coupe, ou se fait caché (B-041). Mesuré des deux côtés, au centre et dos à chaque mur ;
      - toutes ses formes portent un `mark`, et aucune ne saute de plus de 0,5 stud d'une image à l'autre dans un même plan, coup mortel compris (B-031) ;
    - **le nom** : il passe le test des noms des bosses ; il n'est pas déjà un texte du jeu, ni un mot de 3 lettres déjà pris (vérifié à la main) ; il ne reprend aucun nom de la liste du point 4, ni ECLIPSE, EMPEROR, DIVINE, TRUE ou ZERO (décision du 22/10) ;
    - **le son** : sa matière est décidée et notée dans `DECISIONS.md`. Soit il reçoit une matière à lui, faite de nouvelles tables tirées de la palette seulement, et B-033 est corrigé pour lui (recommandé) : les sons que joue sa scène (`sfx`) et ses coups en combat sont alors les siens, et `Kits.test` le vérifie pour les bosses. Soit le repli sur KAI est gardé, et B-033 reste ouvert ;
    - **le test « kit sans finisher »** : la règle « un kit sans finisher joue le fatal classique » reste testée, sur une copie de `MoveData` ou autrement, jamais à vide. Le changement est noté dans `DECISIONS.md` : le test n'est jamais supprimé en silence ;
  - les 9 suites passent.
- **Statut** : `en production`. NOVA faite (v0.36.4, FATAL ERROR) ; KUROEN fait (v0.36.9, BLACK SUN) ; ASURA fait (v0.36.12, SAMSARA), avec trois plans à revoir, non bloquants.
  - **KUROEN SHIN, le dernier, est prêt pour la production.** Rien n'attend Wilhem. Revérifié le 29/10 sur la v0.36.14 (HEAD 4888726) :
    - la v0.36.14 (B-039, B-042) n'a touché que le CLASSÉ entre serveurs et le menu : `GlobalQueue`, `init.server.luau`, `GameModes`, `Locale` (6 textes), `CombatConfig` (la version), `MenuController` et `Lobby.test`. Rien dans `MoveData`, `Finishers`, `CinematicDirector`, `CombatSimulation`, `FighterAI`, `CharacterData`, `PoseLibrary`, `KitFX`, `VfxConfig`, `SoundPalette`, `SoundController`, `CinematicController`, `Animator`, ni dans les tests `Cinematography`, `CombatSimulation`, `Kits`, `CinematicKit` et `Storyboard` (vérifié par `git diff 2a4e820 4888726`) ;
    - toutes ses références tiennent, relues une à une. **Une seule a bougé** : le boss placé en équipe 2, `init.server.luau:687` au lieu de `:676`. **Une est précisée** : `divineFist`, `divineHalo` et `divineSeal` ne sont pas dans `KitFX`, mais dans son thème (`CinematicDirector.luau:4939`), traduits en effets du jeu par `CinematicController.luau:277` ; `KitFX.luau:138` porte ses effets de combat. Des lignes sont ajoutées pour production : le test commun (`:338`, `:385`, `:386`), « languages » (`Lobby.test.luau:322`), les aides du défi d'ASURA (`:1388`, `:1419`), l'esquive mise de côté (`:1878`), `FATAL.fall` (`CinematicDirector.luau:2689-2698`), les corps cachés de SHIN, ZEPHYR et AKEMI (`Finishers.luau:176`, `:758`, `:973`) ;
    - ce que la v0.36.14 change pour lui : rien dans sa scène ni dans son test de défi. Un CHALLENGE reste ouvert après un chargement échoué (seul le CLASSÉ est refusé), et rien ne part pendant l'attente du serveur réservé, ce qui ne touche pas la simulation ;
    - aucun bug bloquant ni majeur n'est ouvert ce matin dans `BUGS.md` (B-043 et B-044, nouveaux, sont mineurs). Le journal de la v0.36.14 propose ensuite « le FATAL FINISHER de KUROEN SHIN avec sa matière sonore (B-033), s'il ne reste aucun bug majeur. Sinon B-044 et B-043 » ;
    - à décider par production, et à noter dans `DECISIONS.md` : son nom ; sa mise en scène ; sa matière sonore (B-033, recommandé : dans la même livraison) ; la nouvelle forme du test « kit sans finisher ».
  - B-034 (le nom du COUP FATAL de KUROEN) attend Wilhem, mais ne bloque pas : seule la liste des noms pris peut grandir.
  - Après lui, les trois plans d'ASURA peuvent passer dans une petite livraison à part : rien ne les attend.
  - Historique : l'idée a été reportée sept matins, du 18 au 25/10, par des bugs passés avant elle (B-011, B-017, B-021, B-020, B-025 et B-032, B-023 et B-028). Puis le 27 et le 28/10 par B-035 et B-039. Tous sont corrigés, B-028 en partie : sa suite attend le relevé des lignes de console sur le jeu publié, que seul Wilhem peut lire. KUROEN SHIN n'en dépend pas.

## I-002 · Étape 4 du pack VFX : les ultimes, puis les arènes et l'interface
- **Date** : 15 octobre 2026.
- **Wilhem** : « Les ultimes (R, ÉVEIL, PORTE), FATAL et FINISHER, les arènes et l'interface arrivent aux étapes 4 à 6. » (LISEZ-MOI de son pack).
- **Interprétation** : c'est la suite du pack VFX de Wilhem.
  - Étape 4 : les ultimes (R, ÉVEIL, PORTE), les FATAL et les FATAL FINISHERS de chaque perso reçoivent les effets dessinés par Wilhem (sceaux, lune, nuages, piliers, ailes…).
  - Étapes 5 et 6 : les arènes, puis l'interface.
- **Ce qui existe** :
  - les étapes 1 à 3 sont branchées (v0.36.0 à v0.36.3) : coups, traînées, impacts, dashs, auras, compétences et passifs des 22 persos ;
  - aujourd'hui, les ultimes, les fatals et les finishers ont leurs effets dessinés par le jeu : la lumière 3D des cinématiques (boules, rayons, anneaux, dômes ; `CinematicController`) ;
  - **le code de l'étape 4 n'est pas dans le pack** : chaque fiche perso du pack dit « Ultimes (R, ÉVEIL, PORTE), FATAL et FINISHER : étape 4 » ;
  - 19 assets du pack sont prévus pour l'étape 4. Ils sont dans `assets/vfx`, sans ID, et le combat ne s'en sert pas :
    - 8 textures : CLOUD_2x2, GLOW_SOFT, LIGHTNING_A, LIGHTNING_C, LIGHTNING_D, MOON, SCREEN_CRACK, SEAL_CIRCLE ;
    - 11 meshes : CLAW3, CONE_FLARE, DOME, FIST_GIANT, FLOOR_DISC, HELIX, PILLAR, SLASH_90, SLASH_360, TWISTER, WING ;
    - le manifeste du pack donne leur usage. Par exemple : SEAL_CIRCLE pour les sceaux d'ultimes et la PORTE, MOON pour MOONFALL et les arènes, WING pour FINAL MERCY et KUROEN SHIN, SCREEN_CRACK pour les FATAL de RYUKEN et AKEMI ;
  - les arènes sont dans `Maps.luau` et `ArenaBuilder.luau`, l'interface dans `UIArt.luau`.
- **Décisions à respecter** (`DECISIONS.md`, 15/10) :
  - « Le PERFECT, l'aura FATAL, le super flash et le K.O. gardent leurs effets du jeu » (Wilhem : « jamais par-dessus le combat ») ;
  - le KIKOHO de KAI reste la boule de ses dessins ;
  - le Red Kamehameha ne coule qu'à l'intérieur du rayon KAIENHA ;
  - un effet du pack ne s'affiche que si tous ses assets ont un ID ;
  - les finishers de SHIN, TARO, KAI et ZEPHYR suivent ses planches (v0.32.0) : leur mise en scène ne doit pas changer.
- **Persos et systèmes touchés** :
  - les 22 persos ;
  - les cinématiques : R, ÉVEIL, PORTE, FATAL, FATAL FINISHERS ;
  - `VfxPack.luau`, `VfxConfig.luau`, `src/client/VFX` ;
  - plus tard, les arènes et l'interface.
- **Valeur / effort** : forte / gros (22 persos × 5 moments, puis les arènes et l'interface).
- **Risques** :
  - la performance sur mobile pendant les ultimes (budget du pack : 40 particules au plus par coup) ;
  - des doublons avec la lumière 3D des scènes actuelles ;
  - les IDs : ces 19 assets s'ajoutent aux 14 meshes déjà attendus.
- **Questions ouvertes** (pour Wilhem) :
  1. Comment avance l'étape 4 ? Choix : a) Wilhem envoie l'étape 4 du pack (code et textures) ; b) production dessine dès maintenant les effets des ultimes avec les 19 assets. **Recommandation : a)**, pour ne pas faire le travail deux fois ni choisir la DA à sa place.
  2. Les IDs des 19 assets (Bulk Import, comme les autres), à envoyer avec ceux des 14 meshes.
  3. Dans les cinématiques, les effets du pack s'ajoutent-ils à la lumière 3D actuelle ou la remplacent-ils ? Choix : a) ils s'ajoutent, la mise en scène reste ; b) ils la remplacent ; c) on décide au cas par cas. **Recommandation : a)**, surtout pour les finishers faits d'après ses planches.
- **Statut** : `à clarifier`. La fiche attend l'étape 4 du pack et les IDs. Rien de nouveau au 29/10 : la v0.36.14 ne touche ni `assets/vfx`, ni `VfxConfig.luau`, ni `src/client/VFX`, ni `VfxPack.luau` (son seul ajout à l'interface est la page « OPPONENT FOUND · CONNECTING… » du CLASSÉ entre serveurs, sans effet du pack). `WING` est toujours à 0 (`VfxConfig.luau:151`). Au 28/10 : la v0.36.13 ne touche ni `assets/vfx`, ni `VfxConfig.luau`, ni `src/client/VFX`, ni `VfxPack.luau` (son seul ajout à l'interface est le bandeau « LOADING YOUR SAVE… » du menu, sans effet du pack). Au 27/10 : `assets/vfx`, `VfxConfig.luau`, `src/client/VFX` et `VfxPack.luau` n'ont pas changé (la v0.36.12 ne touche que la scène d'ASURA, SAMSARA, faite avec la lumière 3D du jeu, comme les autres finishers). Le mesh `WING`, prévu pour ELIAN et KUROEN SHIN, n'a toujours pas d'ID : la scène de KUROEN SHIN ne pourra pas s'en servir.

## I-003 · Le pack VFX vraiment dans la DA du jeu
- **Date** : 15 octobre 2026.
- **Wilhem** : « hésite pas à retravailler pour que ça rentre vraiment dans ma DA ».
- **Interprétation** : les effets du pack doivent avoir l'air du jeu (taille, couleur, quantité), et non d'une démo posée par-dessus.
- **Ce qui existe** :
  - le pack est branché (v0.36.1) ; ses effets ne peuvent pas être vus en jeu d'ici ;
  - depuis la v0.36.2 (complétée en v0.36.3), les planches d'impact du pack sont au cœur de chaque coup, sous la signature du perso. C'est la suite d'une demande de Wilhem du 16 octobre, « pq t'as pas mis les sprites des impacts sur l'update ?? », rangée en bug B-004 ;
  - la taille et l'éclat des effets ne se règlent qu'à l'œil, dans Studio.
- **Persos et systèmes touchés** : les 22 persos, les VFX du combat (`src/client/VFX`, `VfxPack.luau`). Rien sur le combat ni sur l'équilibrage.
- **Valeur / effort** : forte / moyen (des réglages, une fois qu'on voit ce qui ne va pas).
- **Risques** : la performance sur mobile si les effets restent trop chargés.
- **Questions ouvertes** :
  1. Des captures ou des vidéos en jeu de ce qui ne colle pas : trop gros, trop chargé, mauvaise couleur, ou un effet qu'il préférait avant ?
  2. Le premier retour attendu : les planches d'impact de la v0.36.3 sur les coups (taille, éclat). Il faudrait aussi le message de la console Studio si une texture ne charge pas (B-003).
- **Statut** : `à clarifier`. Aucun retour de Wilhem au 29/10 (la v0.36.14 ne touche pas aux VFX).

## I-004 · Rendre aux joueurs touchés par B-021 leur cote 2v2 / 3v3 et l'étoile de leurs titres
- **Date** : 20 octobre 2026 pour la proposition (routine du matin, v0.36.7). Fiche ouverte le 21 octobre 2026.
- **Wilhem** : rien encore. L'idée ne vient pas de lui : la routine la propose dans `BUGS.md` (B-021, piste) et dans le journal (v0.36.7) : « Récupération proposée, non appliquée, à décider par Wilhem : relire la cote dans les classements 2v2 et 3v3, et rendre l'étoile aux titres à exploit possédés sans achat en boutique. »
- **Interprétation** : à sa prochaine connexion, un joueur touché par B-021 retrouve :
  - sa cote CLASSÉE 2v2 et 3v3 : le menu affiche la dernière qu'il avait, au lieu de 1000 ;
  - l'étoile « gagné en jouant » sur ses titres à exploit qu'il n'a pas achetés (UNTOUCHABLE, COMBO ARTIST, FRAME PERFECT, NO MERCY, FINAL BOSS, BREAKER), sans nouvelle annonce « titre gagné ».
  
  Les compteurs des titres pas encore gagnés (par exemple BREAKER à 24 sur 25) restent perdus : rien ne les garde ailleurs.
- **Ce qui existe** (vérifié le 21 octobre 2026) :
  - la cause est corrigée depuis la v0.36.7 (`src/server/Profile.luau`) : plus personne ne perd ces champs. Une sauvegarde qui les contenait encore à la fin de la dernière session les retrouve seule ;
  - **la cote** :
    - les classements `JeuxCombat_Classement_2v2_v1` et `_3v3_v1` (`Matchmaker.BOARDS`) gardent la dernière cote écrite de chaque joueur. Le serveur ne les écrit que pour une catégorie déjà jouée, dans `writeProfile`, après une écriture réussie du profil (`init.server.luau:283-292` de la v0.36.10) ;
    - un joueur qui n'a pas rejoué en 2v2 ou en 3v3 depuis la perte y a donc encore sa dernière cote ;
    - aujourd'hui, le serveur ne lit ces classements que par le haut (les 10 premiers), jamais la ligne d'un joueur ;
  - **l'étoile** :
    - un titre à exploit n'entre dans la liste des titres (`titles`) que de deux façons : acheté avec des pièces (`Store.buyItem`, qui note aussi l'achat dans `ownedItems`), ou gagné en jouant (`GameModes.grantFeatTitles`) ;
    - `ownedItems` est dans les valeurs par défaut du profil depuis la boutique (v0.20.0) : un achat n'a jamais été perdu ;
    - `!give … title` ne l'ajoute pas à `titles` (B-024). Les Game Pass et les Robux ne donnent aucun de ces six titres ;
    - donc un titre à exploit présent dans `titles` sans achat dans `ownedItems` a forcément été gagné en jouant. On peut lui rendre son étoile sans aucune lecture en plus ;
    - FINAL BOSS revient déjà seul, car son compteur est recalculé à partir des notes des défis (`featBosses`), jamais perdues. Mais il ne revient qu'au combat suivant, avec une seconde annonce ;
  - décision du 20/10 (`DECISIONS.md`) : pas de récupération automatique, elle est seulement proposée. Elle touche la cote CLASSÉE, que les joueurs voient ;
  - **relu le 25/10 sur la v0.36.10** (B-025 et B-032, livrée le 24/10). Elle a changé le chargement et l'écriture du profil (`DECISIONS.md`, 23/10) :
    - chaque visite d'un joueur est une session (`SaveQueue`) ;
    - une nouvelle visite attend que l'ancienne libère le profil, jusqu'à 65 s (`SaveQueue.held`, `init.server.luau:159-164`), puis le verrou d'un autre serveur (`:168-217`) ;
    - `writeProfile` (`:253-302`) est le seul point d'écriture du profil. Il n'écrit qu'un profil chargé par sa propre session (« unloaded »), et plus jamais un profil qu'un autre serveur a pris (« lost ») ;
    - le verrou d'un profil chargé est réécrit dès qu'il a 20 s, au vidage suivant (toutes les 15 s), même sans changement (`SaveQueue.RENEW`).

    **Ce que cela change pour la récupération** (à suivre si Wilhem dit oui) :
    - **où** : dans `loadProfile` (`:151-226`), une fois la session chargée (`SaveQueue.loaded`, `:205`), dans son propre fil, pour ne pas retarder l'entrée dans le hub. Jamais sur une session « SAVES UNAVAILABLE » (`:218-224`) : `writeProfile` refuserait d'écrire, et les lectures seraient perdues ;
    - **après chaque lecture** (elle attend la réponse du DataStore) : vérifier que c'est toujours la même visite (`clients[player] == client`, comme le chargement en `:163` et `:180`), et que la catégorie n'a toujours pas de cote (`Matchmaker.played` faux). Sinon, ne rien changer ;
    - **l'écriture** : la récupération n'écrit rien elle-même. Elle change le profil en mémoire (`Matchmaker.setRating`, l'étoile, le marqueur), puis `saveProfile(player, client)` le marque, et le vidage suivant l'écrit par `writeProfile`, comme le reste. Si un autre serveur a pris le profil (« lost »), rien n'est écrit d'ici, ni la cote ni le marqueur : la récupération se refera au prochain chargement. La règle « une seule fois » tient ;
    - **le classement** : après `setRating`, la catégorie compte comme jouée. L'écriture suivante remet donc la même cote dans le classement (`:284-291`) : une écriture de plus, sans effet ;
    - **le budget** : les renouvellements du verrou (2 écritures par minute pour un joueur inactif) et les essais d'un chargement qui attend un autre serveur (un toutes les 3 s) prennent aussi sur le budget DataStore du serveur. Raison de plus pour ne faire les deux lectures qu'une fois par joueur.

    Rien de cela ne change la question posée à Wilhem, ni la recommandation. La fiche reste à clarifier : la réponse attend toujours Wilhem.
  - **relu le 26/10 sur la v0.36.11** (B-023 et B-028 en partie, livrée le 25/10) :
    - **ce qui ne bouge pas** : le chargement et l'écriture du profil, `Profile.luau` et `Matchmaker.luau`. La v0.36.11 ne touche `init.server.luau` qu'après la ligne 580 : toutes les lignes citées plus haut tiennent (`:151-226`, `:159-164`, `:168-217`, `:205`, `:218-224`, `:253-302`, `:283-292`) ;
    - **ce qui change** : `endVersus` compte maintenant chaque place avec sa propre part (`AntiCheat.versusShares`, décision D1 du 25/10). En CLASSÉ 2v2 ou 3v3, celui qui part perd toujours ses points, même à la première seconde. Pour un joueur touché par B-021, la cote d'une catégorie sans cote vaut 1000 (`Matchmaker.ratingOf`). Il repart donc de 1000, moins sa perte, et la catégorie compte comme jouée (`Matchmaker.played`) : la récupération ne se lancera plus pour lui. Avant la v0.36.11, un départ dans les 25 premières secondes ne touchait pas sa cote, et il restait récupérable. C'est une façon de plus de devenir irrécupérable : la recommandation « vite » compte encore plus ;
    - **sans effet** : celui qui reste après un départ rapide (part 0) ne reçoit aucune cote, et reste récupérable. Un match arrêté par une mise à jour (NO CONTEST, décision D3) ne touche à aucune cote ;
    - **B-035** (trouvé par la chasse du 25/10, mineur, ouvert) touche la même fenêtre : pendant l'attente du chargement, un CLASSÉ se lance sur le profil par défaut, à 1000. La récupération part après `SaveQueue.loaded`, donc après la fusion : sa règle tient. Il reste un cas rare. Un joueur touché fait sa première visite depuis la v0.36.7 : sa sauvegarde n'a pas encore de champ `ratings`. S'il finit un CLASSÉ 2v2 ou 3v3 pendant l'attente, la fusion garde la cote jouée sur 1000, faute de champ à reprendre dans la sauvegarde (`Profile.merge`), et la récupération ne se lance plus. Si sa sauvegarde a déjà ce champ, la fusion efface le match (le tableau de B-035), et la récupération reste possible. Corriger B-035 avant elle, ou avec elle (la piste `needsSave` : aucun CLASSÉ avant le chargement), ferme ce cas. C'est la recommandation pour production, si Wilhem dit oui.

    La question posée à Wilhem et la recommandation ne changent pas.
  - **relu le 28/10 sur la v0.36.13** (B-035, livrée le 27/10) :
    - **ce qui change** : pendant le chargement de la sauvegarde, seul TRAINING se lance, et TRAINING n'écrit rien dans le profil. Les trois voies d'un CLASSÉ sont gardées : la garde de `start` (`GameModes.waitsForSave`, `init.server.luau:1652`), le DÉFI accepté qui reste en attente (`Lobby.accept`, `:1417`), et le serveur réservé du CLASSÉ entre serveurs, qui attend les deux profils jusqu'à 65 s puis ne lance pas le match (`GlobalQueue.crossStart`, `:1192`) ;
    - **le lien avec B-035 est levé.** Le cas rare du 26/10 (un CLASSÉ 2v2 ou 3v3 fini pendant l'attente, gardé par la fusion faute de champ `ratings` dans la sauvegarde, et qui rendait le joueur irrécupérable) ne peut plus arriver : aucun CLASSÉ ne part avant la fin du chargement. Une session « SAVES UNAVAILABLE » peut jouer, mais rien n'est écrit, ni le profil ni les classements (`writeProfile` refuse « unloaded » en `:264`, avant toute écriture de classement) : le joueur reste récupérable à la session suivante. Le critère « B-035 corrigé avec elle, ou le cas rare noté dans `DECISIONS.md` » tombe. Il devient : la garde de B-035 reste entière ;
    - **ce qui reste, et que la v0.36.13 rend plus simple à fermer** : les modes s'ouvrent maintenant exactement à la fin du chargement (`client.profileLoaded`, `:212`), donc au moment où une récupération dans son propre fil commencerait ses deux lectures. Un joueur qui lance tout de suite un CLASSÉ 2v2 entre dans la file à 1000 (`:1669-1670`). Si la lecture répond pendant le match, la cote est rendue en plein match, et la fin du match compte bien la cote rendue (`endVersus` relit la cote à la fin, `:771`) : seul l'appariement s'est fait à 1000. Rien n'est perdu, et la règle « jamais écraser une cote jouée » tient ;
    - **une option nouvelle pour production** : faire les deux lectures **dans** le chargement, après `SaveQueue.loaded` (`:206`) et avant `client.profileLoaded = true` (`:212`). Le bandeau « LOADING YOUR SAVE… » reste alors le temps des deux lectures, une seule fois par joueur grâce au marqueur. Aucun mode ne part avant la cote rendue, pas même le CLASSÉ du serveur réservé. La raison de l'ancien choix, « ne pas retarder l'entrée dans le hub », ne tient plus : depuis la v0.36.13, le joueur est dans le hub pendant le chargement, seuls les modes attendent. Le prix : une lecture lente retarde les modes. Il faut donc un seul essai par lecture, sous `pcall`, sans nouvel essai pendant le chargement ; une lecture en échec est refaite à la connexion suivante. **Recommandation : dans le chargement.** Production choisit, ce n'est pas une question pour Wilhem ;
    - **le menu** : la cote 2v2 et 3v3 s'affiche en texte simple sur la page CLASSEMENT (`MenuController.luau:2034-2036`), sans compteur qui monte. Faite dans le chargement, la récupération est déjà dans le statut de fin (`onProfileLoaded`, `:1328-1343`, statut en `:1342`). Faite dans un fil à part, il faut un `menuStatus` après elle, sinon le menu montre 1000 jusqu'au statut suivant ;
    - **B-036** (ouvert, la copie superficielle de `writeProfile`, `table.clone` en `:266`) : la cote rendue vit dans `ratings`, une table imbriquée partagée avec une écriture déjà partie ; le marqueur, au premier niveau, ne l'est pas. Au pire, la sauvegarde garde la cote rendue sans le marqueur. C'est sans danger : une cote présente suffit à ne plus relancer la récupération (`Matchmaker.played`) ;
    - **sans effet** : B-039 (le premier arrivé sur le serveur réservé) ne joue qu'une fois son profil chargé ; `Profile.luau`, `Matchmaker.luau`, `Store.luau` et `Admin.luau` n'ont pas changé ;
    - **les lignes à jour** (le serveur a gagné une ligne avant `loadProfile`, et 9 avant `writeProfile`) : `loadProfile` `:152-228` ; l'attente de l'ancienne visite `:156-165` ; celle du verrou d'un autre serveur `:166-218` ; « même visite » `:164` et `:181` ; `SaveQueue.loaded` `:206` ; `profileLoaded` `:212` (réussite) et `:219` (échec) ; « SAVES UNAVAILABLE » `:219-226` ; `writeProfile` `:262-311` ; les classements 2v2 et 3v3 `:292-301`, écrits après le profil (`:297`). Les lignes citées plus haut pour la v0.36.10 et la v0.36.11 sont celles de ces versions.

    La question posée à Wilhem et la recommandation ne changent pas : la v0.36.13 ferme une façon de devenir irrécupérable, mais pas la principale (rejouer ou quitter un CLASSÉ 2v2 ou 3v3 après la perte).
  - **relu le 29/10 sur la v0.36.14** (B-039 et B-042, livrée le 28/10). La question : la v0.36.14 refuse le CLASSÉ après un chargement échoué ; est-ce que cela touche la récupération de la cote 2v2 et 3v3 ?
    - **la réponse courte : non, pas sa règle.** La récupération ne se lance que sur une session chargée (`SaveQueue.loaded`), jamais sur une session « SAVES UNAVAILABLE ». Le nouveau refus ne vise que ces sessions-là : `GameModes.saveState` vaut alors `"failed"`, et `GameModes.startRefusal` refuse le CLASSÉ (`init.server.luau:1708`). Les deux ne se croisent jamais ;
    - **pour les joueurs touchés, rien ne change non plus** : avant la v0.36.14, une session en échec pouvait jouer un CLASSÉ 2v2 ou 3v3 à 1000, mais rien n'en était écrit, ni le profil ni les classements (`writeProfile` refuse « unloaded » en `:275`, avant les classements, `:303-312`). Le joueur restait récupérable. Depuis, il ne joue plus ce CLASSÉ du tout : même résultat pour lui, et son adversaire n'est plus compté contre 1000. Le refus couvre les trois catégories (1v1, 2v2, 3v3 : le même `VERSUS` en file `RANKED`) et le serveur réservé (`crossStart` annule dès qu'un chargement échoue, `:1236`) ;
    - **ce qui change pour production, et rend l'option « dans le chargement » encore plus juste** :
      - un seul état décide de tout : `saveState` (`init.server.luau:238-240`, `GameModes.saveState`). Tant que `client.profileLoaded` n'est pas vrai, il vaut `"loading"`. Si les deux lectures se font entre `SaveQueue.loaded` (`:206`) et `client.profileLoaded = true` (`:212`), tout reste refusé sauf TRAINING, et le serveur réservé attend (`crossStart` rend `"wait"`). Le CLASSÉ 2v2 ou 3v3, local ou entre serveurs, part donc toujours avec la cote rendue. Rien à ajouter à `startRefusal` ;
      - le serveur réservé n'annule plus au bout de 65 s : il attend la fin du chargement, sous un filet, `PROFILE_CAP` = 120 s (`GlobalQueue.luau:160`). Le test de B-039 (`Lobby.test.luau:1519`) garde ce filet au-dessus du plus long chargement, recalculé sur le miroir `saveWorld` (`:625`) : 81 s et 26 appels au DataStore, à 1 s par appel (`:1647-1660`). Deux lectures dans le chargement en font 28 au plus : 109 s, toujours sous 120 s. **Mais le miroir doit les compter**, sinon le test ne mesure plus le vrai chargement. Attention : le plus long chargement du test est celui qui échoue, alors que les lectures ne se font que sur un chargement réussi. Le test doit prendre le plus long des deux ;
      - dans un fil à part (l'autre option), le serveur réservé lance le CLASSÉ dès que les deux profils sont chargés, sans attendre les lectures. L'appariement s'est fait sur le serveur d'origine, avec la cote de la sauvegarde. Le match compte la cote rendue si elle arrive avant la fin (`endVersus` relit la cote à la fin, `:790`). Mais si le match finit avant la lecture, la catégorie compte comme jouée, et la récupération ne se fait plus. C'est rare, et c'est une raison de plus pour la recommandation ;
    - **un trou qui existait déjà, que la v0.36.14 rend simple à fermer si production le veut** : le chargement réussit, mais une lecture échoue. Le marqueur n'est pas posé, et la lecture sera refaite à la connexion suivante. En attendant, le joueur peut jouer un CLASSÉ 2v2 ou 3v3 à 1000 : la catégorie devient jouée, et il n'est plus récupérable. `GameModes.startRefusal` est maintenant le seul endroit où un mode est refusé avec sa raison : on pourrait y refuser le CLASSÉ de cette catégorie pour la session. **Recommandation : ne pas le faire.** Un échec de lecture est rare, et un CLASSÉ 2v2 fermé toute une session se verrait. C'est un choix de production, à noter dans `DECISIONS.md`, pas une question pour Wilhem ;
    - **sans effet** : B-043 (un CLASSÉ contre soi-même, avec des données falsifiées) ne touche que le tricheur ; B-044 (des réclamations perdues) ne touche aucune cote ; `startVersus`, qui sort maintenant les deux joueurs de toute file et de tout match (B-039), ne touche pas au profil. `Profile.luau`, `Matchmaker.luau`, `Store.luau` et `Admin.luau` n'ont pas changé ;
    - **les lignes à jour** (le serveur a gagné 11 lignes en `:236-246`, avant `writeProfile`, puis d'autres plus loin) : `loadProfile` `:152-228` (inchangé) ; « même visite » `:164` et `:181` ; `SaveQueue.loaded` `:206` ; `profileLoaded` `:212` (réussite) et `:219` (échec) ; « SAVES UNAVAILABLE » `:219-226` ; `saveState` `:238-240` ; `writeProfile` `:273-322`, « unloaded » `:275`, la copie de B-036 (`table.clone`) `:277`, les classements 2v2 et 3v3 `:303-312`, écrits après le profil (`:308`) ; `endVersus` relit la cote en `:790` ; la garde de `start` (`GameModes.startRefusal`) en `:1708`, et la file locale prend la cote en `:1726` ; le DÉFI (`Lobby.accept`) en `:1470` ; le serveur réservé (`crossStart`) en `:1236` ; `onProfileLoaded` `:1378-1392` (le statut de fin en `:1392`) ; le menu, page CLASSEMENT, `MenuController.luau:2032-2038`. Les lignes citées plus haut pour la v0.36.10, la v0.36.11 et la v0.36.13 sont celles de ces versions.

    La question posée à Wilhem et la recommandation ne changent pas.
- **Persos et systèmes touchés** :
  - aucun perso, rien sur le combat ni l'équilibrage ;
  - le chargement du profil (`init.server.luau`, `Profile.luau`), la cote CLASSÉE (`Matchmaker`), les titres et leur étoile (`GameModes`), les classements (DataStore) ;
  - le menu montre le résultat. Aucun texte nouveau à traduire si le retour se fait en silence.
- **Valeur / effort** : moyenne / petit.
  - Valeur : elle ne concerne que les joueurs touchés, mais c'est leur progression visible (la cote CLASSÉE, et l'étoile qui distingue un titre gagné d'un titre acheté).
  - Effort : pour l'étoile, une règle pure avec un test ; pour la cote, deux lectures au chargement et un test de la règle.
- **Risques** :
  - **des lectures en plus à chaque connexion** :
    - relire la cote coûte deux lectures DataStore (une par classement) pour chaque joueur sans cote 2v2 ou 3v3. C'est le cas de la plupart des joueurs, qui n'ont jamais joué ces modes. Sans limite, ces lectures se feraient à chaque connexion, pour toujours, et pour rien ;
    - elles prennent sur le budget DataStore du serveur, le même que celui des profils et du CLASSÉ entre serveurs ;
    - la parade : **une seule fois par joueur**. Un marqueur dans le profil (un champ de plus dans `Profile.default`, vérifié par le test « saved profile ») n'est posé que si les deux lectures ont répondu. La lecture ne bloque pas l'entrée dans le hub, et elle n'écrase jamais une cote jouée entre-temps ;
  - **des cas où la cote relue est fausse** :
    - le classement est écrit après le profil, à part (`init.server.luau:288` de la v0.36.10). Si cette écriture a échoué, il garde une cote plus ancienne, et c'est elle qui revient ;
    - un joueur qui a rejoué en 2v2 ou en 3v3 après la perte est reparti de 1000. Sa vraie cote est perdue, et le classement a gardé la nouvelle. La récupération ne peut rien pour lui (elle ne se lance pas, puisqu'il a une cote). Depuis la v0.36.11, c'est vrai aussi pour un CLASSÉ 2v2 ou 3v3 quitté tout de suite ;
    - chaque jour où la v0.36.7 tourne en ligne sans la récupération, des joueurs touchés rejouent et ne peuvent plus être récupérés. Si la v0.36.7 n'est pas encore publiée sur Roblox, mieux vaut publier les deux ensemble ;
    - si un jour une cote est remise à zéro exprès (nouvelle saison, tricheur) sans vider les classements, la relecture la rendrait. Rien ne le fait aujourd'hui, et le marqueur « une seule fois » écarte ce cas ;
  - **des cas où l'étoile est fausse** :
    - un titre acheté puis gagné en jouant ne retrouve pas son étoile, car on ne peut pas le distinguer d'un titre seulement acheté. Le joueur doit refaire l'exploit ;
    - si un jour un titre à exploit est donné autrement (récompense de quête, cadeau du propriétaire sans `ownedItems`), la règle lui mettrait une étoile à tort. Un commentaire dans le code et le test doivent le rappeler.
- **Questions ouvertes** (pour Wilhem) :
  1. Faut-il rendre ce qui a été perdu ? Choix : a) oui, la cote et les étoiles ; b) seulement les étoiles (aucune lecture en plus, aucun risque de valeur fausse) ; c) non, on laisse comme c'est. **Recommandation : a)**, une seule fois par joueur, en silence, et vite : chaque jour, moins de joueurs peuvent retrouver leur cote.
- **Statut** : `à clarifier`. Rendre une cote CLASSÉE que les joueurs voient est un choix de Wilhem (décision du 20/10). Relue le 25/10 après la v0.36.10, puis le 26/10 après la v0.36.11 : la fiche suit le nouveau chargement et les nouvelles règles de départ. Revue le 27/10 : la v0.36.12 ne touche ni le serveur (`src/server`), ni `Profile.luau`, ni `Matchmaker.luau`, ni `GameModes.luau`, et toutes les lignes citées tiennent. **Relue le 28/10 après la v0.36.13** : B-035 est corrigé, et le lien avec lui est levé (aucun CLASSÉ ne part plus pendant le chargement). Une option de production s'ajoute (les deux lectures dans le chargement), sans rien demander de plus à Wilhem. **Relue le 29/10 après la v0.36.14** : le CLASSÉ refusé après un chargement échoué ne touche pas la récupération (elle ne tourne jamais sur une session en échec), et l'option « dans le chargement » gagne : le serveur réservé attend maintenant la fin du chargement. Un critère s'ajoute (le miroir du test de B-039 compte les deux lectures). Aucune décision de Wilhem n'est arrivée depuis.
- **Critères d'acceptation** (si Wilhem dit oui) :
  - une règle pure (dans `Profile.luau` ou `GameModes`), testée dans `Lobby.test` :
    - au chargement, un titre à exploit présent dans `titles` et sans achat dans `ownedItems` reçoit son étoile ;
    - un titre acheté n'en reçoit pas, un titre hors des six n'est jamais touché ;
    - aucune annonce « titre gagné » ;
  - à la connexion, pour une catégorie sans cote (`Matchmaker.played` faux), le serveur lit la ligne du joueur dans le classement 2v2 ou 3v3. S'il y trouve un nombre, `Matchmaker.setRating` le rend ; sinon, rien ne change ;
  - une seule fois par joueur : le marqueur figure dans `Profile.default` et n'est posé que si les deux lectures ont répondu. Une lecture en échec est refaite à la connexion suivante ;
  - la lecture n'empêche jamais le chargement de finir : au plus deux lectures, un seul essai chacune, sous `pcall`. Une cote jouée entre-temps n'est jamais écrasée ;
  - elle ne se lance qu'une fois la session chargée (`SaveQueue.loaded`), jamais sur une session « SAVES UNAVAILABLE ». Après chaque lecture, elle ne change rien si la visite a changé ;
  - elle n'écrit rien elle-même : la cote, l'étoile et le marqueur passent par `saveProfile`, puis par `writeProfile`, comme le reste du profil ;
  - la garde de B-035 (v0.36.13) et celles de B-039 et B-042 (v0.36.14) restent entières : aucun mode, sauf TRAINING, ne part avant la fin du chargement ; aucun CLASSÉ après un chargement échoué ; rien pendant l'attente du serveur réservé (`GameModes.startRefusal`). Si les lectures sont faites dans le chargement (avant `client.profileLoaded`), le CLASSÉ part avec la cote rendue, local ou entre serveurs. Si elles sont faites dans un fil à part, un `menuStatus` suit la récupération. Le choix est noté dans `DECISIONS.md` ;
  - si les lectures sont dans le chargement, le miroir `saveWorld` du test de B-039 (`Lobby.test.luau`) les compte, et `PROFILE_CAP` reste au-dessus du plus long chargement, réussi (avec les deux lectures) ou échoué ;
  - le cas « chargement réussi, lecture en échec, CLASSÉ 2v2 joué avant la connexion suivante » est tranché par production et noté dans `DECISIONS.md` (recommandé : on l'accepte, sans fermer le CLASSÉ) ;
  - le test « saved profile » passe avec le nouveau champ, et les 9 suites passent ;
  - rien n'est affirmé testé sur le vrai DataStore : Wilhem confirme en jeu (un joueur touché revoit sa cote 2v2).
