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

Dernier tri : 27 octobre 2026 (routine du matin, sur la v0.36.12, HEAD 8c1c308).

## I-001 · Un FATAL FINISHER pour NOVA, KUROEN, ASURA et KUROEN SHIN
- **Date** : 12 octobre 2026 pour l'idée (v0.27.0) ; ces quatre persos attendent depuis la v0.33.0.
- **Wilhem** :
  - « une animation comme les Legendary Finish de DBL quand le fatal tue, une anime spéciale plus longue » (rappelé en tête de `Finishers.luau`) ;
  - la règle : « seulement sur la deuxième vie… si l'adversaire n'a pas peu d'HP et l'utilisateur du final n'a pas déjà un round gagné, le FATAL FINISHER s'active pas, il y a juste le fatal classique » (journal, v0.27.0).
- **Interprétation** : quand le COUP FATAL de l'un de ces quatre persos tue, le joueur voit une scène d'environ 10 s propre au perso. Cette scène est le K.O. lui-même, avec le nom du finisher.
- **Où on en est** (27 octobre 2026) : trois persos sur quatre sont faits. **Il ne reste que KUROEN SHIN, et il est prêt.**
  - **NOVA, faite (v0.36.4)** : FATAL ERROR (ERREUR FATALE), 11 s. Huit drones se rangent en rail d'anneaux devant son gantelet, puis un compte 3-2-1-0 et un seul tir ; la cible « bugue », puis tombe. « ZERO HOUR » a été écarté (décision du 17/10). Trois bugs de sa scène se suivent dans `BUGS.md` et ne rouvrent pas l'idée : B-012 (la visière dans sa tête, ouvert), B-013 et B-014 (à confirmer en jeu par Wilhem) ;
  - **KUROEN, fait (v0.36.9)** : BLACK SUN (SOLEIL NOIR), 10,7 s. Les trois marques de DOMINATION s'allument dans son dos. Trois coups (genou, coude, paume) laissent chacun un petit soleil noir sur la cible. Les trois soleils volent dans son poing levé et n'en font plus qu'un, puis AXE OF NIGHT abat la cible des deux poings. Deux points se suivent ailleurs et ne rouvrent pas l'idée :
    - ses trois coups sont ceux de sa chope, ECLIPSE CLINCH : assumé pour cette livraison, à revoir par Wilhem (`DECISIONS.md`, 22/10) ;
    - le grand soleil saute de 3,6 studs au coup mortel (B-031, cosmétique, ouvert) ;
  - **ASURA, fait (v0.36.12)** : SAMSARA (le même mot en français), 10,7 s. Produit, validé et livré le 26/10. Trois plans sont à revoir, sans bloquer : voir « ASURA · SAMSARA », plus bas ;
  - **KUROEN SHIN : rien encore.** Il joue toujours son fatal classique, 真 · ETERNAL ECLIPSE. Voir « Pour KUROEN SHIN », plus bas.
- **Ce qui existe pour tous** (revérifié le 27/10 sur la v0.36.12) :
  - **21 kits ont leur finisher** : les 20 persos jouables et ASURA. Chacun a une ligne `Finisher = { Name, Length, FinalTick }` dans `MoveData.luau` et une scène dans `Finishers.luau` (une fonction `S.KIT` dans `Finishers.build`, `:50`). Le réalisateur cherche la scène sous le nom du kit de l'attaquant (`CinematicDirector.luau:5179`) ;
  - **la règle de déclenchement** est dans `CombatSimulation` et ne change pas : un COUP FATAL qui tue, lancé par un perso qui a déjà gagné une manche (ou mis K.O. un perso d'un relais). La ligne `Finisher` se lit sur le kit de l'attaquant (`kitOf`, `CombatSimulation.luau:175-177`, utilisé en `:1330-1332`). Depuis la v0.36.8 (B-020), « qui tue » veut dire un vrai K.O. : `finish` vaut `fells`, sauf si la cible va se relever (la première vie d'ASURA, seul kit avec une seconde vie) ;
  - **les tests de `tests/Cinematography.test.luau`** :
    - le test commun de tous les finishers : au moins 6 plans propres au perso, un nom qui n'est celui d'aucun coup d'un autre kit, le K.O. avec son nom après le coup mortel, la cible à terre à la fin (pose `DownFace`), des sons de la palette ;
    - chaque finisher joué dos au mur, des deux côtés (v0.36.5), et chaque COUP FATAL classique aussi (v0.36.6) ;
    - la mesure du sujet caché par l'autre corps, `Kit.hiddenShare` (`tests/CinematicKit.luau`), et la fonction `film(kit, center, mirror, wall)` (`:598`). Elles servent aux 6 tests de placement de BLACK SUN (`:613-672`) et à ceux de SAMSARA (`:880-938`). **Un nouveau finisher n'y entre pas tout seul** : il lui faut ses propres tests ;
    - **nouveau en v0.36.12** : le test des noms des finishers des bosses (`:947-998`). KUROEN SHIN y entrera tout seul (voir « les noms déjà pris », plus bas) ;
  - **les tests de `tests/CombatSimulation.test.luau`** :
    - le test « kit sans finisher » (`:1322-1351`) prend le premier kit sans ligne `Finisher`, les bosses en dernier. **Depuis la v0.36.12, c'est KUROEN SHIN, le seul qui reste.** Ce test échouera exprès (« no kit left without a finisher ») quand KUROEN SHIN aura sa ligne ;
    - le vrai défi d'ASURA (`:1377-1476`) : ASURA contre une équipe de 3, dans ses deux vies, et jamais de finisher contre un seul perso. C'est le modèle du test de défi de KUROEN SHIN.
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
    - **B-040** (ouvert, cosmétique) : au tick 470 (plan `asura-ss-blown`, `Finishers.luau:3334`), la cible se retourne d'un coup au sol, comme dans 17 autres finishers ;
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
    - la cible finit face contre terre (`DownFace`, exigé par le test commun), mais sans se retourner d'un coup au milieu d'un plan (B-040 : sa tête saute de plus de 4 studs en une image dans 18 finishers sur 21). Elle tombe directement face contre terre, ou le passage de `DownImpact` à `DownFace` tombe sur une coupe ;
    - jouer aussi la cible **au plus près du mur** : les placements « cible près du mur » de BLACK SUN et de SAMSARA ne la mettent jamais au-delà de x = 25,3, et le sol va jusqu'à 28 ;
    - le test des noms des bosses laisse passer un nom **égal** à un texte qui existe déjà (un thème de la boutique, une provocation) : vérifier à la main que le nom n'est pas déjà une clé de `Locale` avant de l'y ajouter.
- **Pour KUROEN SHIN (le dernier), ce que production doit savoir** (préparé le 24/10, revérifié le 27/10 sur la v0.36.12) :
  - **où en est le code** (la v0.36.12 a ajouté 4 lignes à `MoveData`, la ligne `Finisher` d'ASURA : les lignes de son kit ont bougé de 4) :
    - `Finishers.luau` : rien pour lui. **Son nom contient une espace** : sa scène s'écrira `S["KUROEN SHIN"] = function(ctx, frame, a, d, tick, dir)` dans `Finishers.build`, et non `function S.KUROEN SHIN`. C'est sous ce nom exact que le réalisateur la cherche (`cin.kit`). Sa planche demandera des guillemets : `luau tests/Storyboard.luau -a "KUROEN SHIN" Fatal - 1 20` ;
    - `MoveData.luau` : son kit `:1419-1447` (`kit("KUROEN SHIN", …)` en `:1427`), sans ligne `Finisher`. Il ne prend pas celle de KUROEN : BLACK SUN reste à KUROEN seul. Ses rôles sont ceux de KUROEN (`Roles = table.clone(base.Roles)`, `:1430`) : son COUP FATAL est `KuroenFatal` (蝕 · TOTAL ECLIPSE dans `MoveData`, `:785`, 300 de jauge), affiché avec le nom de son thème. À côté : son titre de PORTE (真 · TRUE EMPEROR, `:1444`), sa DOMINATION (`:1437-1438`), sa chope à lui (`Throws["KUROEN SHIN"]`, `:1573-1576`) et `MoveKit`, qui ignore les bosses (`:1460-1474`) ;
    - `CinematicDirector.luau` : son thème, `GEN.add("KUROEN SHIN")` (`:4928-4941`). Son FATAL : 真 · ETERNAL ECLIPSE, archétype `pillar` (des piliers de lumière appelés du ciel sur la cible, de loin), ouverture `emerge` (il sort du sol, dans son sceau), fin `skyward` (un uppercut envoie la cible vers le ciel) ;
    - son niveau de CPU : `ultimate = 1` (`FighterAI.luau:75-77`) ; son style et celui de KUROEN : `CharacterData.luau:211-212` ;
    - depuis la v0.36.12, les storyboards le dessinent dans ses couleurs (son premier style, TRUE EMPEROR), la cible en KAI (`Kit.characters`).
  - **son identité** :
    - 真, « KUROEN au-delà de toute limite » (sa description, `Locale`). Wilhem le voulait « cassé comme Gogeta » (journal, v0.17.0 ; « like Gogeta in FighterZ » en tête de son kit) et plus fort qu'ASURA (« SHIN », v0.23.22). C'est le boss du CHALLENGE · KUROEN SHIN, jamais jouable (il n'est pas dans `KitOrder`) ;
    - blanc et or : cheveux blancs à pointes d'or, yeux d'or, gilet et chemise blanc cassé (F4F0E6) bordés d'or, pantalon noir, ki FFE9A0. Il n'a qu'un style, TRUE EMPEROR ;
    - son allure : debout et calme, les mains basses et ouvertes, « pas de garde à tenir » (`PoseLibrary`). Il ouvre ses ultimes en lévitation (`Levitate`), et entre en scène debout (`StandTall`) ;
    - ce qui le rend « cassé » : l'INSTINCT DIVIN (le premier coup qui l'atteint est esquivé, et il réapparaît dans le dos de l'attaquant), un dash qui traverse les coups (« transmission instantanée »), et la DOMINATION née en ÉCLIPSE (niveau III), qui ne se perd jamais. Son thème le résume : « il est derrière toi avant que tu le voies » ;
    - ses effets : poing, auréole et sceau divins (`KitFX` : `divineFist`, `divineHalo`, `divineSeal`). Dans le pack (6.22) : un éclat blanc avec des plumes de lumière, et un dash en téléportation, trois images fantômes blanches puis un anneau d'or.
  - **son son, et B-033** (revérifié le 27/10) :
    - il n'a pas de matière à lui dans `SoundPalette.MATERIALS` (`SoundPalette.luau:57`). `material(kit)` rend alors celle de KAI (`SoundController.luau:32-34`). En combat, ses élans, ses pas et les temps de sa chope sonnent donc comme KAI, et ses coups comme KUROEN (`MoveKit`, `:186`) ;
    - **dans sa scène, ce serait pire que pour ASURA** : les sons que la scène joue elle-même (`whoosh`, `heavy`) prennent le kit de l'attaquant (`CinematicController.luau:760`, `SoundController:cinematicSound`, `:137-147`), donc ceux de KAI pour lui ; et le coup mortel que porte la simulation (`KuroenFatal`) sonne comme KUROEN. Sa scène sonnerait KAI et KUROEN, jamais lui. ASURA, lui, a sa matière : les sons de sa scène étaient bien les siens. Les sons communs (`boom`, `charge`) ne dépendent d'aucun kit ;
    - c'est B-033 (mineur, ouvert depuis le 24/10). Sa piste : une entrée `["KUROEN SHIN"]` faite de **nouvelles tables** (par exemple celles de KUROEN, un peu plus graves, en salle), jamais `MATERIALS["KUROEN SHIN"] = MATERIALS.KUROEN`, car `SoundController.new` range chaque liste sous `kit .. "." .. part` (`:47`) ; le choix de la matière dans une fonction pure de `SoundPalette`, testée ; les vérifications de `Kits.test` étendues aux bosses. Pas d'acier (`slash`) : il frappe des poings ;
    - **recommandation : corriger B-033 avant sa scène, ou avec elle** : la question de sa matière est alors réglée une fois, pour la scène et pour le combat. Si production garde le repli sur KAI, elle le note dans `DECISIONS.md`, et B-033 reste ouvert.
  - **ses ultimes, à ne pas recopier** (`GEN.add("KUROEN SHIN")`) :
    - R, 真 · DIVINE EMPEROR RUSH : la cible tirée vers lui à chaque coup (`pull`) ;
    - ÉVEIL, 真 · ZERO ABSOLU: TRUE ECLIPSE : une tempête de poings de tous les côtés, avec ses images fantômes (`gatling`, ouverture `clones`) ;
    - PORTE, 真 · TRUE EMPEROR : il tourne autour de la cible plus vite que l'œil (`orbit`) ;
    - FATAL, 真 · ETERNAL ECLIPSE : il sort du sol, des piliers de lumière tombent du ciel sur la cible, un uppercut l'envoie en l'air (`pillar`, `skyward`) ;
    - **sa chope** : la cible soulevée d'une main par la gorge, le ki pulse deux fois, la paume qui l'envoie (`MoveData.Throws`) ;
    - **et ceux de KUROEN, dont il reprend les coups** :
      - BLACK SUN : les trois marques qui s'allument dans le dos, trois coups (genou, coude, paume), trois petits soleils, AXE OF NIGHT des deux poings ;
      - sa chope ECLIPSE CLINCH (genou, coude, paume) ;
      - son R (des coups de tous les côtés, de plus en plus vite), son ÉVEIL (la lumière s'éteint, une éclipse rouge dans le ciel), sa PORTE (une tempête de poings), son FATAL (le jonglage sous l'éclipse) ;
    - **et SAMSARA**, un autre perso mais le même or : ni la roue, ni des poings qui prennent feu un à un.
  - **le piège de son double** :
    - le style ÉCLIPSE DIVINE de KUROEN, gagné en battant KUROEN SHIN, a **exactement** ses couleurs (`CharacterData.luau:211-212`). Et BLACK SUN prend le ki du style (`ctx.characters[A].Energy`). Un joueur en ÉCLIPSE DIVINE joue donc déjà un BLACK SUN blanc et or, avec le visage de KUROEN SHIN ;
    - sa scène doit se distinguer de BLACK SUN **par ses gestes et son déroulé**, pas seulement par ses couleurs ;
    - une piste, pas une consigne : ce qu'aucune de ses scènes ne montre encore, c'est l'INSTINCT DIVIN (le coup esquivé, lui déjà dans le dos) et son calme (les mains basses, sans garde).
  - **la couleur** :
    - le blanc et la lumière sont aussi à ELIAN. FINAL MERCY, c'est la paume, le pilier, sept auréoles, le blanc, la croix, des ailes. Le pack donne à KUROEN SHIN les plumes d'ELIAN (`FEATHER_2x2`) ;
    - le mesh d'aile (`WING`) est prévu pour ELIAN et pour lui, mais il n'a pas d'ID (`VfxConfig` : 0). Il n'est donc pas utilisable ;
    - un pilier de lumière est déjà pris deux fois : par son propre FATAL et par FINAL MERCY. La PORTE de RAIJIN appelle déjà des piliers de foudre ;
    - l'or FFD23F est celui d'ASURA (SAMSARA compris), de KAI en SACRÉ et en ÉVEILLÉ, et du thème OR de la boutique ;
    - la scène doit se lire « KUROEN au-delà de toute limite » : des poings, des coudes, des genoux, l'empereur. Elle ne doit pas se lire « ange » ou « lumière ».
  - **les noms déjà pris** :
    - les 21 finishers : MAXIMUM KAIENHA, DEMPSEY ROLL: FINAL ROUND, GALE EXCALIBUR, THOUSAND SHADOWS, TEN FISTS OF RAGE, FINAL DIVISION, INVERTED WORLD, THRONE OF RUINS, SPEAR OF THE THUNDER GOD, FROZEN REQUIEM, TOXIC FEAST, TITAN QUAKE, STELLAR COLLAPSE, RESONANCE, CAGE OF CLAWS, CRIMSON COVENANT, THE GREAT HUNT, FINAL MERCY, FATAL ERROR, BLACK SUN, **SAMSARA** ;
    - les siens : 真 · DIVINE EMPEROR RUSH, 真 · ZERO ABSOLU: TRUE ECLIPSE, 真 · ETERNAL ECLIPSE, 真 · TRUE EMPEROR, TRUE DOMINATION (son passif), DIVINE INSTINCT, son style TRUE EMPEROR, les titres du défi (GOD SLAYER, ECLIPSE BREAKER, TRUE EMPEROR'S EQUAL, TRUE EMPEROR), les succès GOD SLAYER et TRUE EMPEROR, la provocation ECLIPSED ;
    - ceux de KUROEN : ses 29 coups (dont AXE OF NIGHT, RISING UPPER, CROWN BREAKER, FALLING EMPEROR, SOVEREIGN UPPER, TYRANT'S FIST, EMPEROR'S DECREE, ECLIPSE BREAKER, CRIMSON STEP, EMPEROR RUSH, 零 · ZERO ABSOLU: ECLIPSE, 皇 · EMPEROR'S GATE, 蝕 · TOTAL ECLIPSE), EMPEROR STEP, DOMINATION, BLACK SUN, ses styles (EMPEROR, BLOOD MOON, DIVINE ECLIPSE) ;
    - **le test des noms des bosses (v0.36.12) le lira tout seul**. Son nom ne pourra être ni un coup, ni un ultime de thème, ni un titre de PORTE, ni un passif, ni un titre, ni un succès. Il ne pourra être dans aucun autre texte du jeu (`Locale`), et aucun de ses mots de 4 lettres ou plus ne pourra être déjà dans plus de deux textes. Compté le 27/10 sur `Locale`, ces mots sont donc refusés d'office : ECLIPSE (19 textes), FINAL (15), DIVINE (14), EMPEROR (11), LIGHT (9), LAST (9), ZERO (8), INSTINCT (6), TRUE (5), HEAVEN (5), PALM (5), KING (5), BLACK (4), THRONE (4), GOLD (3), JUDGMENT (3). INSTINCT aussi, alors que l'INSTINCT DIVIN est une piste pour sa scène : le geste peut le montrer, pas le nom ;
    - **ce que ce test ne voit pas** : les mots de 3 lettres (GOD est déjà dans GOD SLAYER, GOD SLAIN 👑 et SPEAR OF THE THUNDER GOD ; SUN dans BLACK SUN) ; et un nom **égal** à un texte qui existe déjà, par exemple un thème de la boutique (GOLD, PHANTOM, INFERNO, SAKURA, ABYSS) ou une provocation. À vérifier à la main ;
    - **B-034** (ouvert, attend Wilhem) : le COUP FATAL de KUROEN, celui qu'il emprunte, porte le nom de la PORTE de DAICHA, « 蝕 · TOTAL ECLIPSE » (`MoveData.luau:785` et `:617`). Pour lui, rien ne change à l'écran : son thème affiche son FATAL sous son propre nom. Mais si KUROEN est renommé avant sa scène, ce nouveau nom s'ajoute à la liste des noms pris. Le test des noms des bosses n'échoue pas sur ce doublon (il ne lit que les finishers des bosses).
  - **ses pièges à lui** :
    - **en défi, depuis la droite** : le boss est l'équipe 2, qui commence à droite (`Sim.setTeams(world, request.team, { boss })`, `init.server.luau:668`). Les planches et les tests depuis la droite comptent autant que les autres ;
    - **la cible** est l'un des 20 persos jouables, avec son arme s'il en a une. Les outils prennent KAI : garder de la marge (B-018) ;
    - **aucun outil à étendre** : il n'a ni arme ni bras en plus. Les outils le dessinent avec le corps de KAI, comme KUROEN ;
    - **sa DOMINATION est toujours au niveau III** (`Start = 3`, `NoLoss` ; pack : « comme KUROEN, en or »). Allumer les trois marques une à une, comme BLACK SUN, n'aurait pas de sens pour lui : elles sont déjà allumées ;
    - **son INSTINCT DIVIN** esquive le premier coup qui l'atteint. Dans son test de défi, seul lui frappe, comme dans celui d'ASURA. Si le test doit le toucher, mettre son esquive de côté, comme les tests de B-020 ;
    - **la scène sera rare**, comme celle d'ASURA. Il faut, à la fois : un défi à 2 ou 3 persos, dont un déjà mis K.O. par lui ; sa vie sous 30 % (900 PV sur 3 000) ; son COUP FATAL pas encore utilisé (un par match) ; un coup qui tue. Le CPU lance son COUP FATAL dès qu'il est prêt (`ultimate = 1`). Il n'a pas de seconde vie, et ses cibles non plus : `finish` vaut `fells`, rien à changer (B-020).
  - **le test « kit sans finisher », à refaire** : quand il aura sa ligne, il n'y aura plus de vrai kit à jouer. La règle « un kit sans finisher joue le fatal classique » doit rester testée autrement, et le changement est noté dans `DECISIONS.md`, jamais supprimé en silence. Une piste : `Sim.newWorld` reçoit `MoveData` en paramètre, et la règle lit `world.moveData.Kits` (`CombatSimulation.luau:175-177`). Le test peut donc lui passer une copie de `MoveData` où un kit n'a pas de ligne `Finisher`. Production choisit.
- **Persos et systèmes touchés** :
  - faits : NOVA (drones et gantelets, orange FF8A2A), KUROEN (éclipse rouge et noire, E0102E), ASURA (KAI à quatre bras, boss, or FFD23F) ;
  - reste KUROEN SHIN (boss, blanc et or) : `MoveData.luau` (sa ligne `Finisher`), `Finishers.luau` (`S["KUROEN SHIN"]`), `Locale.luau` (le nom en français), `PoseLibrary.luau` s'il a des poses de scène à lui, `tests/Cinematography.test.luau` (sa scène, ses placements), `tests/CombatSimulation.test.luau` (son défi, et le test « kit sans finisher » à refaire), storyboards. Aucun outil de test à étendre ;
  - si B-033 est corrigé avec lui : `SoundPalette.luau`, `SoundController.luau` (client) et `tests/Kits.test.luau` ;
  - pour les trois plans d'ASURA : `Finishers.luau` seulement, avec ses tests ;
  - aucun dégât ni aucune vie : pas d'équilibrage.
- **Valeur / effort** : forte / gros pour l'idée entière, une scène par livraison.
  - KUROEN SHIN : valeur moindre, car sa scène sera rare. Effort : celui de KUROEN, plus le test « kit sans finisher » à refaire, plus B-033 s'il passe avec lui.
  - Les trois plans d'ASURA : petit effort.
- **Risques** :
  - les bosses ne déclenchent leur finisher qu'en relais, avec leur vie sous 30 % et leur COUP FATAL prêt. Un boss n'est jouable nulle part, même au labo : sa scène se verra rarement en combat, et surtout sur les storyboards ;
  - KUROEN SHIN reprend les coups de KUROEN, et KUROEN en ÉCLIPSE DIVINE joue déjà BLACK SUN dans ses couleurs : sa scène doit se distinguer par ses gestes ;
  - sans B-033, sa scène sonnerait comme KAI et KUROEN, jamais comme lui ;
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
    - sa ligne `Finisher` est sur son kit, et sa scène est `S["KUROEN SHIN"]`. BLACK SUN ne change pas : ses 7 tests passent sans retouche ;
    - la scène ne reprend aucune de ces scènes : ni sa chope (la gorge, d'une main), ni celle de KUROEN (genou, coude, paume) ; ni les étapes de BLACK SUN (les marques qui s'allument, les trois soleils, AXE OF NIGHT des deux poings) ; ni ses ultimes (la cible tirée vers lui, la tempête de poings, le tour autour d'elle, les piliers de lumière) ; ni la roue de SAMSARA ;
    - un test joue le vrai défi : KUROEN SHIN contre une équipe de 3. Il met le premier perso K.O., puis son COUP FATAL tue le deuxième : la scène joue, sans VICTORY, et le troisième entre après elle. Contre un seul perso, jamais de finisher ;
    - la scène est vérifiée depuis la droite autant que depuis la gauche (au centre, dos au mur, storyboard) ;
    - un placement de plus : la cible au plus près du mur (au-delà de x = 25,3), des deux côtés, avec les mêmes exigences (sol, caméra, sujet caché) ;
    - sur la planche, des deux côtés : lui toujours entier dans le cadre quand il est le sujet, et ses mains lisibles (pas de forte plongée qui les cache derrière son corps) ;
    - la cible ne se retourne pas d'un coup au sol au milieu d'un plan (B-040) : elle tombe directement face contre terre, ou le passage de `DownImpact` à `DownFace` tombe sur une coupe ;
    - toutes ses formes portent un `mark`, et aucune ne saute de plus de 0,5 stud d'une image à l'autre dans un même plan, coup mortel compris (B-031) ;
    - son nom passe le test des noms des bosses, n'est pas déjà un texte du jeu (vérifié à la main), ne reprend aucun nom de la liste « les noms déjà pris », et évite les mots usés de sa famille (ECLIPSE, EMPEROR, DIVINE, TRUE, ZERO), comme BLACK SUN l'a fait (décision du 22/10) ;
    - la règle « un kit sans finisher joue le fatal classique » reste testée, autrement qu'avec un vrai kit. Le changement est noté dans `DECISIONS.md` : le test n'est jamais supprimé en silence ;
    - sa matière sonore est décidée et notée dans `DECISIONS.md` : soit le repli sur KAI est gardé, et B-033 reste ouvert ; soit il reçoit une matière à lui, faite de nouvelles tables tirées de la palette seulement, et B-033 est corrigé pour lui (recommandé). Les sons que joue sa scène (`sfx`) sont alors les siens ;
  - les 9 suites passent.
- **Statut** : `en production`. NOVA faite (v0.36.4, FATAL ERROR) ; KUROEN fait (v0.36.9, BLACK SUN) ; **ASURA fait (v0.36.12, SAMSARA)**, produit, validé et livré le 26/10, avec trois plans à revoir, non bloquants.
  - **KUROEN SHIN, le dernier, est prêt pour la production.** Rien n'attend Wilhem. Revérifié le 27/10 sur la v0.36.12 (HEAD 8c1c308) :
    - la v0.36.12 n'a touché que la scène d'ASURA et ce qui l'entoure : `Finishers`, `MoveData` (sa ligne `Finisher`), `Locale` (SAMSARA), `PoseLibrary`, `FourArms`, `CombatConfig` (la version), les tests et les outils de test. Rien dans `CinematicDirector`, `CombatSimulation`, `FighterAI`, `CharacterData`, `SoundPalette`, ni dans le client ou le serveur ;
    - toutes ses références tiennent, relues une à une. Seules celles de `MoveData` ont bougé de 4 lignes : son kit (`:1419-1447`, au lieu de `:1415-1443`), sa chope (`:1573-1576`, au lieu de `:1569-1572`), `MoveKit` (`:1460-1474`). Les deux « 蝕 · TOTAL ECLIPSE » de B-034 sont toujours en `:617` et `:785` ;
    - ce que la v0.36.12 lui apporte : le test des noms des bosses, qui le lira tout seul ; les storyboards dans ses couleurs ; le modèle du test de défi ; les leçons de SAMSARA ;
    - aucun bug bloquant ni majeur n'est ouvert dans `BUGS.md` ce matin. Le journal propose B-035 (mineur mais visible) avant lui : production choisit, rien n'oblige à passer un bug avant lui ;
    - à décider par production, et à noter dans `DECISIONS.md` : son nom ; sa matière sonore (B-033, recommandé : la corriger avant sa scène ou avec elle) ; la nouvelle forme du test « kit sans finisher ».
  - B-034 (le nom du COUP FATAL de KUROEN) attend Wilhem, mais ne bloque pas : seule la liste des noms pris peut grandir.
  - Historique : l'idée a été reportée sept matins, du 18 au 25/10, par des bugs passés avant elle (B-011, B-017, B-021, B-020, B-025 et B-032, B-023 et B-028). Ils sont tous corrigés depuis, B-028 en partie : sa suite attend le relevé des lignes de console sur le jeu publié, que seul Wilhem peut lire. KUROEN SHIN n'en dépend pas.

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
- **Statut** : `à clarifier`. La fiche attend l'étape 4 du pack et les IDs. Rien de nouveau au 27/10 : `assets/vfx`, `VfxConfig.luau`, `src/client/VFX` et `VfxPack.luau` n'ont pas changé (la v0.36.12 ne touche que la scène d'ASURA, SAMSARA, faite avec la lumière 3D du jeu, comme les autres finishers). Le mesh `WING`, prévu pour ELIAN et KUROEN SHIN, n'a toujours pas d'ID : la scène de KUROEN SHIN ne pourra pas s'en servir.

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
- **Statut** : `à clarifier`. Aucun retour de Wilhem au 27/10.

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
- **Statut** : `à clarifier`. Rendre une cote CLASSÉE que les joueurs voient est un choix de Wilhem (décision du 20/10). Relue le 25/10 après la v0.36.10, puis le 26/10 après la v0.36.11 : la fiche suit le nouveau chargement et les nouvelles règles de départ. Revue le 27/10 : la v0.36.12 ne touche ni le serveur (`src/server`), ni `Profile.luau`, ni `Matchmaker.luau`, ni `GameModes.luau`, et toutes les lignes citées tiennent. Aucune décision de Wilhem n'est arrivée depuis.
- **Critères d'acceptation** (si Wilhem dit oui) :
  - une règle pure (dans `Profile.luau` ou `GameModes`), testée dans `Lobby.test` :
    - au chargement, un titre à exploit présent dans `titles` et sans achat dans `ownedItems` reçoit son étoile ;
    - un titre acheté n'en reçoit pas, un titre hors des six n'est jamais touché ;
    - aucune annonce « titre gagné » ;
  - à la connexion, pour une catégorie sans cote (`Matchmaker.played` faux), le serveur lit la ligne du joueur dans le classement 2v2 ou 3v3. S'il y trouve un nombre, `Matchmaker.setRating` le rend ; sinon, rien ne change ;
  - une seule fois par joueur : le marqueur figure dans `Profile.default` et n'est posé que si les deux lectures ont répondu. Une lecture en échec est refaite à la connexion suivante ;
  - la lecture ne bloque pas le chargement, et une cote jouée entre-temps n'est jamais écrasée ;
  - elle ne se lance qu'une fois la session chargée (`SaveQueue.loaded`), jamais sur une session « SAVES UNAVAILABLE ». Après chaque lecture, elle ne change rien si la visite a changé ;
  - elle n'écrit rien elle-même : la cote, l'étoile et le marqueur passent par `saveProfile`, puis par `writeProfile`, comme le reste du profil ;
  - si B-035 est encore ouvert, il est corrigé avec elle (aucun CLASSÉ ne part avant le chargement). Sinon, le cas rare du CLASSÉ fini pendant l'attente est noté dans `DECISIONS.md` ;
  - le test « saved profile » passe avec le nouveau champ, et les 9 suites passent ;
  - rien n'est affirmé testé sur le vrai DataStore : Wilhem confirme en jeu (un joueur touché revoit sa cote 2v2).
